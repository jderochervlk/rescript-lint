import { chmodSync, copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const repository = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const pinnedVersions = { rescript: '12.3.1', '@rescript/react': '0.15.0', 'rescript-vitest': '3.0.1' };

const run = (binary, args, cwd) => {
  const result = spawnSync(binary, args, { cwd, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
  if (result.error !== undefined) return { status: 2, output: result.error.message };
  return { status: result.status ?? 2, output: result.stdout + result.stderr, stdout: result.stdout };
};

const catalog = text => {
  const parts = text.split(/^### `([^`]+)`\s*$/m);
  return parts.slice(1).reduce((state, part, index) => {
    if (index % 2 === 0) return { ...state, name: part };
    const code = /```rescript\n([\s\S]*?)```/.exec(part)?.[1];
    const section = text.slice(0, text.indexOf(`### \`${state.name}\``)).split(/^## /m).at(-1) ?? '';
    const id = section.startsWith('JSX Accessibility') ? `jsx-a11y/${state.name}` : state.name;
    return { ...state, entries: [...state.entries, { id, code }] };
  }, { name: '', entries: [] }).entries;
};

const halves = entry => {
  if (entry.code === undefined) return { error: `No ReScript fence for ${entry.id}.` };
  const invalid = /^\/\/ Invalid.*$/m.exec(entry.code);
  const valid = /^\/\/ Valid.*$/m.exec(entry.code);
  if (invalid === null || valid === null || invalid.index >= valid.index) {
    return { error: `Expected ordered Invalid and Valid markers for ${entry.id}.` };
  }
  const shared = entry.code.slice(0, invalid.index);
  return { values: [
    { kind: 'Invalid', text: shared + entry.code.slice(invalid.index, valid.index) },
    { kind: 'Valid', text: shared + entry.code.slice(valid.index) },
  ] };
};

const scaffold = (id, text) => {
  if (['no-empty-file', 'require-license-header', 'require-interface', 'no-restricted-modules'].includes(id)) return text;
  if (id === 'no-useless-catch') return `let readConfig = Prelude.readConfig\n\n${text}`;
  return `open Prelude\n\n${text}`;
};

const fixtureCases = (entries, root) => entries.flatMap((entry, index) => {
  const split = halves(entry);
  if (split.error !== undefined) return [{ id: entry.id, error: split.error }];
  return split.values.map(({ kind, text }) => {
    const module = `Example${String(index + 1).padStart(3, '0')}${kind}`;
    return { id: entry.id, kind, module, file: resolve(root, 'src', `${module}.res`), text: scaffold(entry.id, text).trimEnd() + '\n' };
  });
});

const writeChanged = (file, text) => {
  if (existsSync(file) && readFileSync(file, 'utf8') === text) return;
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, text);
};

const prepare = (root, cases) => {
  cases.forEach(fixture => writeChanged(fixture.file, fixture.text));
  writeChanged(resolve(root, 'src', 'Prelude.res'), readFileSync(resolve(repository, 'scripts/rule-example-prelude.res'), 'utf8'));
  writeChanged(resolve(root, 'src', 'Database.res'), 'module User = {let find = id => id}\n');
  writeChanged(resolve(root, 'src', 'UserService.res'), 'let find = id => id\n');
  const paired = cases.find(fixture => fixture.id === 'require-interface' && fixture.kind === 'Valid');
  if (paired !== undefined) writeChanged(paired.file.replace(/\.res$/, '.resi'), 'type t\nlet make: string => t\n');
  const consumed = cases.find(fixture => fixture.id === 'no-unused-export' && fixture.kind === 'Valid');
  if (consumed !== undefined) writeChanged(resolve(root, 'src', 'CatalogConsumer.res'), `let main = () => ${consumed.module}.recordRequest(())\n`);
};

const versions = root => Object.fromEntries(Object.keys(pinnedVersions).map(name => {
  const manifest = JSON.parse(readFileSync(resolve(root, 'node_modules', name, 'package.json'), 'utf8'));
  return [name, manifest.version];
}));

const reanalyze = root => {
  const result = run(resolve(root, 'node_modules/.bin/rescript-tools'), ['reanalyze', '-dce', '-json', '-live-names', 'main'], root);
  if (result.status !== 0) return { available: false, reason: result.output };
  try {
    const report = JSON.parse(result.stdout);
    if (!Array.isArray(report)) return { available: false, reason: 'Reanalyze did not produce a diagnostic array.' };
    const file = resolve(root, 'catalog-reanalyze.json');
    writeFileSync(file, JSON.stringify(report, null, 2) + '\n');
    return { available: true, file, diagnostics: report.length };
  } catch (error) {
    return { available: false, reason: `Cannot decode real Reanalyze output: ${String(error)}` };
  }
};

const configuration = (root, ids, analysis) => {
  const config = { root, jsxRuntime: 'react-dom', testFramework: 'rescript-vitest-3',
    rules: Object.fromEntries(ids.map(id => [id, false])), restrictedModules: ['Database'],
    entryModules: ['CatalogConsumer'], license: 'MIT', maxNesting: 2, maxParams: 3,
    maxLinesPerFunction: 5, maxNestedDescribe: 2, deepEqualityThreshold: 2, maxLines: 6, maxSwitchCases: 2,
    ...(analysis.available ? { reanalyzeReport: analysis.file } : {}) };
  const file = resolve(root, 'catalog-lint.json');
  writeChanged(file, JSON.stringify(config, null, 2) + '\n');
  return file;
};

const inspect = (binary, config, analysis, fixture) => {
  if (fixture.id === 'no-unused-export' && !analysis.available) {
    return { id: fixture.id, kind: fixture.kind, file: fixture.file, skipped: true, reason: analysis.reason };
  }
  const result = run(binary, ['--config', config, '--enable-rule', fixture.id, fixture.file]);
  const diagnostics = [...result.output.matchAll(/error \[([^\]]+)\]/g)].map(match => match[1]);
  const finding = diagnostics.includes(fixture.id);
  const passes = fixture.kind === 'Invalid'
    ? result.status === 1 && finding && diagnostics.every(id => id === fixture.id)
    : result.status === 0 && diagnostics.length === 0;
  return { id: fixture.id, kind: fixture.kind, file: fixture.file, status: result.status, output: result.output, finding, passes };
};

const audit = (binary, root, ids, cases, installed) => {
  prepare(root, cases);
  const compiled = run(resolve(root, 'node_modules/.bin/rescript'), ['build'], root);
  const compilation = { status: compiled.status, versions: installed, ...(compiled.status === 0 ? {} : { output: compiled.output }) };
  if (compiled.status !== 0) return { compilation, checked: 0, passed: 0, skipped: 0, failures: [], error: 'Compiler verification failed; no lint examples were counted.' };
  const analysis = reanalyze(root);
  const config = configuration(root, ids, analysis);
  const results = cases.map(fixture => inspect(binary, config, analysis, fixture));
  const skips = results.filter(result => result.skipped === true);
  const failures = results.filter(result => result.skipped !== true && !result.passes);
  return { compilation, reanalyze: analysis, checked: results.length - skips.length,
    passed: results.length - skips.length - failures.length, skipped: skips.length, failures, skips };
};

const main = () => {
  const [binaryArgument, fixtureArgument] = process.argv.slice(2);
  if (binaryArgument === undefined || fixtureArgument === undefined) {
    process.stderr.write('Usage: node scripts/audit-rule-examples.mjs BINARY FIXTURE_PROJECT\nThe temporary project must already contain the pinned compiler and adapter dependencies.\n');
    return 2;
  }
  const binary = resolve(binaryArgument);
  const root = resolve(fixtureArgument);
  const installed = versions(root);
  const mismatch = Object.keys(pinnedVersions).filter(name => installed[name] !== pinnedVersions[name]);
  if (mismatch.length !== 0) { process.stderr.write(`Expected pinned versions ${JSON.stringify(pinnedVersions)}; found ${JSON.stringify(installed)}\n`); return 2; }
  const snapshot = resolve(root, 'catalog-linter');
  copyFileSync(binary, snapshot);
  chmodSync(snapshot, 0o755);
  const listing = run(snapshot, ['--list-rules']);
  if (listing.status !== 0) { process.stderr.write(listing.output); return 2; }
  const ids = listing.output.trim().split('\n').map(line => line.trim().split(/\s+/)[0]);
  const entries = catalog(readFileSync(resolve(repository, 'docs/RULE_EXAMPLES.md'), 'utf8'));
  const cases = fixtureCases(entries, root);
  const invalid = cases.filter(fixture => fixture.error !== undefined);
  if (invalid.length !== 0) { process.stderr.write(JSON.stringify(invalid, null, 2) + '\n'); return 2; }
  const report = { ...audit(snapshot, root, ids, cases, installed),
    binarySha256: createHash('sha256').update(readFileSync(snapshot)).digest('hex') };
  const reportFile = resolve(root, 'catalog-audit.json');
  writeFileSync(reportFile, JSON.stringify(report, null, 2) + '\n');
  process.stdout.write(JSON.stringify({ ...report, reportFile }, null, 2) + '\n');
  return report.error !== undefined ? 2 : report.failures.length === 0 && report.skipped === 0 ? 0 : 1;
};

try { process.exitCode = main(); }
catch (error) { process.stderr.write(String(error) + '\n'); process.exitCode = 2; }
