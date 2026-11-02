import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, symlinkSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, isAbsolute, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';

const repository = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
export const pinnedVersions = { rescript: '12.3.1', '@rescript/react': '0.15.0', 'rescript-vitest': '3.0.1' };
const ruleId = /^[a-z][a-z0-9-]*(?:\/[a-z][a-z0-9-]*)*$/;
// Unknown opens intentionally stop throw-name resolution in exception rules.
const noPrelude = new Set(['no-empty-file', 'require-license-header', 'max-lines', 'no-useless-catch']);
const fileMarker = /^\/\/\s*(src\/[^\s]+?\.resi?)(?=$|[\s:])/;

const sections = text => {
  const lines = text.split(/\r?\n/);
  const headings = [];
  let inFence = false;
  lines.forEach((line, index) => {
    if (/^\s*```/.test(line)) inFence = !inFence;
    else if (!inFence) {
      const match = /^(#{1,6})\s+(.+?)\s*$/.exec(line);
      if (match !== null) headings.push({ index, level: match[1].length, title: match[2] });
    }
  });
  if (inFence) throw new Error('Unclosed Markdown code fence.');
  return headings.map((heading, index) => ({
    ...heading,
    end: headings.slice(index + 1).find(next => next.level <= heading.level)?.index ?? lines.length,
    lines,
  }));
};

const fenced = (section, language, end = section.end) => {
  const blocks = [];
  for (let index = section.index + 1; index < end; index += 1) {
    const opening = /^\s*```(\S*)\s*$/.exec(section.lines[index]);
    if (opening === null) continue;
    const start = ++index;
    while (index < end && !/^\s*```\s*$/.test(section.lines[index])) index += 1;
    if (index === end) throw new Error(`Unclosed ${opening[1]} code fence.`);
    if (opening[1] === language) blocks.push(section.lines.slice(start, index).join('\n'));
  }
  return blocks;
};

const configuration = (id, section) => {
  const blocks = fenced(section, 'json');
  if (blocks.length !== 1) throw new Error(`Expected one JSON configuration fence for ${id}.`);
  const config = JSON.parse(blocks[0]);
  if (config === null || Array.isArray(config) || typeof config !== 'object' ||
      config.rules === null || Array.isArray(config.rules) || typeof config.rules !== 'object' ||
      config.rules[id] !== true) throw new Error(`Configuration for ${id} must set rules["${id}"] to true.`);
  return { config, configSource: blocks[0] };
};

const pairHeading = section => {
  const match = /^(Incorrect|Correct)(?::\s*(.+))?$/.exec(section.title);
  return match === null ? null : { ...section, kind: match[1], scenario: match[2] ?? 'primary' };
};

const examplePair = (id, scenario, headings, common, configuration) => {
  const halves = ['Incorrect', 'Correct'].map(kind => {
    const matching = headings.filter(heading => heading.scenario === scenario && heading.kind === kind);
    if (matching.length === 0) throw new Error(`Missing ${kind} example for ${id}: ${scenario}.`);
    if (matching.length > 1) throw new Error(`Duplicate ${kind} example for ${id}: ${scenario}.`);
    const blocks = fenced(matching[0], 'rescript');
    if (blocks.length === 0) throw new Error(`Missing ${kind} ReScript code for ${id}: ${scenario}.`);
    return [...common, ...blocks];
  });
  return { id, scenario, incorrect: halves[0], correct: halves[1], ...configuration };
};

export const parsePage = (id, text) => {
  if (!ruleId.test(id)) throw new Error(`Invalid rule ID: ${id}`);
  const all = sections(text);
  if (all.filter(section => section.level === 1).length !== 1 ||
      all.find(section => section.level === 1)?.title !== `\`${id}\``) {
    throw new Error(`Expected page title # \`${id}\`.`);
  }
  const examples = all.filter(section => section.level === 2 && section.title === 'Examples');
  const configs = all.filter(section => section.level === 2 && section.title === 'Configuration');
  if (examples.length === 0) throw new Error(`Missing ## Examples for ${id}.`);
  if (configs.length === 0) throw new Error(`Missing ## Configuration for ${id}.`);
  if (examples.length > 1 || configs.length > 1) throw new Error(`Duplicate example/configuration section for ${id}.`);
  const config = configuration(id, configs[0]);
  const headings = all.filter(section => section.level === 3 &&
    section.index > examples[0].index && section.index < examples[0].end)
    .map(pairHeading).filter(heading => heading !== null);
  const scenarios = [...new Set(headings.map(heading => heading.scenario))];
  if (!scenarios.includes('primary')) throw new Error(`Missing primary example pair for ${id}.`);
  const common = fenced(examples[0], 'rescript', headings[0].index);
  return scenarios.map(scenario => examplePair(id, scenario, headings, common, config));
};

export const safeSourcePath = filename => {
  const path = filename.replaceAll('\\', '/');
  if (path.startsWith('/') || /^[A-Za-z]:/.test(path) ||
      path.split('/').some(part => part === '..' || part === '.' || part === '')) {
    throw new Error(`Unsafe fixture path: ${filename}`);
  }
  const source = path.startsWith('src/') ? path.slice(4) : path;
  if (!/\.resi?$/.test(source)) throw new Error(`Expected a ReScript source path: ${filename}`);
  return source;
};

const namedFiles = block => {
  const files = [];
  let current;
  for (const line of block.split('\n')) {
    const marker = fileMarker.exec(line);
    if (marker !== null) {
      current = { path: safeSourcePath(marker[1]), lines: [] };
      files.push(current);
    } else if (/^\/\/\s*src[/\\]/.test(line)) {
      throw new Error(`Invalid source filename comment: ${line}`);
    } else if (current !== undefined) current.lines.push(line);
    else if (line.trim() !== '') throw new Error('Explicit file examples need a filename comment before their code.');
  }
  return files.map(file => ({ path: file.path, text: file.lines.join('\n') + '\n' }));
};

export const extractFiles = blocks => {
  if (!blocks.some(block => /^\/\/\s*src[/\\]/m.test(block))) {
    return [{ path: 'Example.res', text: blocks.join('\n\n') + '\n' }];
  }
  const files = blocks.flatMap(namedFiles);
  if (new Set(files.map(file => file.path)).size !== files.length) {
    throw new Error('Duplicate source filename in example fences.');
  }
  return files;
};

const run = (binary, args, cwd) => {
  const result = spawnSync(binary, args, { cwd, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
  return { status: result.status ?? 2, output: result.error?.message ?? (result.stdout + result.stderr), stdout: result.stdout ?? '' };
};

const write = (file, text) => {
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, text);
};

const prepareCase = (root, directory, pair, kind, ids, prelude) => {
  mkdirSync(directory, { recursive: true });
  symlinkSync(resolve(root, 'node_modules'), resolve(directory, 'node_modules'), 'junction');
  write(resolve(directory, 'rescript.json'), JSON.stringify({
    name: 'rule-documentation-audit', sources: [{ dir: 'src', subdirs: true }],
    jsx: { version: 4 }, dependencies: ['@rescript/react', 'rescript-vitest'],
    'package-specs': { module: 'esmodule', 'in-source': false },
  }));
  const blocks = pair[kind === 'Incorrect' ? 'incorrect' : 'correct'];
  const explicit = blocks.some(block => /^\/\/\s*src[/\\]/m.test(block));
  const usePrelude = !explicit && !noPrelude.has(pair.id);
  const files = extractFiles(blocks).map(file => ({
    ...file, text: usePrelude ? `open Prelude\n\n${file.text}` : file.text,
  }));
  if (usePrelude) write(resolve(directory, 'src/Prelude.res'), prelude);
  files.forEach(file => write(resolve(directory, 'src', file.path), file.text));
  write(resolve(directory, 'documented-config.json'), pair.configSource);
  const config = {
    ...pair.config, root: '.',
    rules: { ...Object.fromEntries(ids.map(id => [id, false])), [pair.id]: true },
  };
  write(resolve(directory, 'rescript-lint.json'), JSON.stringify(config));
  return { directory, files: files.map(file => resolve(directory, 'src', file.path)), config };
};

const analyze = (root, fixture, id) => {
  if (id !== 'no-unused-export') return { available: true };
  const result = run(resolve(root, 'node_modules/.bin/rescript-tools'),
    ['reanalyze', '-dce', '-json', '-live-names', 'main'], fixture.directory);
  if (result.status !== 0) return { available: false, reason: result.output };
  const report = JSON.parse(result.stdout);
  if (!Array.isArray(report)) return { available: false, reason: 'Reanalyze did not produce a diagnostic array.' };
  const file = resolve(fixture.directory, fixture.config.reanalyzeReport);
  const path = relative(fixture.directory, file);
  if (isAbsolute(path) || path.startsWith('..')) throw new Error('Reanalyze report must stay inside its fixture project.');
  write(file, result.stdout);
  return { available: true, file, diagnostics: report.length };
};

export const assessLint = (id, kind, result) => {
  let report;
  try { report = JSON.parse(result.stdout); }
  catch { return { passes: false, error: 'Linter did not return diagnostic JSON.', output: result.output }; }
  if (report === null || typeof report !== 'object' ||
      !Array.isArray(report.diagnostics) || !Array.isArray(report.errors)) {
    return { passes: false, error: 'Linter returned an invalid diagnostic envelope.', output: result.output };
  }
  const onlyTarget = report.diagnostics.every(finding => finding !== null && typeof finding === 'object' && finding.rule === id);
  const passes = report.errors.length === 0 && onlyTarget && (kind === 'Incorrect'
    ? result.status === 1 && report.diagnostics.length > 0
    : result.status === 0 && report.diagnostics.length === 0);
  return { passes, status: result.status, report };
};

const auditCase = (root, binary, pair, kind, fixture) => {
  const configured = run(binary, ['--format', 'json', '--config', 'documented-config.json',
    '--inspect-config', fixture.files[0]], fixture.directory);
  if (configured.status !== 0) return { stage: 'configuration', passes: false, output: configured.output };
  const built = run(resolve(root, 'node_modules/.bin/rescript'), ['build'], fixture.directory);
  if (built.status !== 0) return { stage: 'compile', passes: false, output: built.output };
  const proof = analyze(root, fixture, pair.id);
  if (!proof.available) return { stage: 'analysis', passes: false, output: proof.reason };
  const checked = run(binary, ['--format', 'json', '--config', 'rescript-lint.json', ...fixture.files], fixture.directory);
  return { stage: 'lint', analysis: proof, ...assessLint(pair.id, kind, checked) };
};

const registeredIds = (binary, root) => {
  const listed = run(binary, ['--list-rules'], root);
  if (listed.status !== 0) throw new Error(listed.output);
  const ids = listed.stdout.trim().split(/\r?\n/).map(line => {
    const match = /^(\S+) \((?:enabled|disabled)\)$/.exec(line);
    if (match === null || !ruleId.test(match[1])) throw new Error(`Invalid rule listing: ${line}`);
    return match[1];
  });
  if (ids.length === 0 || new Set(ids).size !== ids.length) throw new Error('Expected a nonempty unique rule inventory.');
  return ids;
};

const installedVersions = root => {
  const versions = Object.fromEntries(Object.keys(pinnedVersions).map(name => [
    name, JSON.parse(readFileSync(resolve(root, 'node_modules', name, 'package.json'), 'utf8')).version,
  ]));
  if (Object.keys(pinnedVersions).some(name => versions[name] !== pinnedVersions[name])) {
    throw new Error(`Expected pinned versions ${JSON.stringify(pinnedVersions)}; found ${JSON.stringify(versions)}`);
  }
  return versions;
};

const audit = (root, binary, ids, pairs) => {
  const directory = mkdtempSync(resolve(root, 'catalog-cases-'));
  const prelude = readFileSync(resolve(repository, 'scripts/examples/rule-example-prelude.res'), 'utf8');
  return pairs.flatMap((pair, index) => ['Incorrect', 'Correct'].map(kind => {
    const project = resolve(directory, `${index}-${kind}`);
    const fixture = prepareCase(root, project, pair, kind, ids, prelude);
    const result = auditCase(root, binary, pair, kind, fixture);
    return { id: pair.id, scenario: pair.scenario, kind, project, ...result };
  }));
};

const main = () => {
  const [binaryArgument, fixtureArgument] = process.argv.slice(2);
  if (binaryArgument === undefined || fixtureArgument === undefined) {
    process.stderr.write('Usage: node scripts/examples/audit-rule-examples.mjs BINARY FIXTURE_PROJECT\nThe temporary project must already contain the pinned compiler and adapter dependencies.\n');
    return 2;
  }
  const root = resolve(fixtureArgument);
  const versions = installedVersions(root);
  const binary = resolve(root, 'catalog-linter');
  copyFileSync(resolve(binaryArgument), binary);
  chmodSync(binary, 0o755);
  const ids = registeredIds(binary, root);
  const pairs = ids.flatMap(id => parsePage(id, readFileSync(resolve(repository, 'docs/rules', `${id}.md`), 'utf8')));
  const results = audit(root, binary, ids, pairs);
  const failures = results.filter(result => !result.passes);
  const report = {
    compilation: { status: results.some(result => result.stage === 'compile') ? 1 : 0, versions },
    total: results.length, checked: results.filter(result => result.stage === 'lint').length,
    passed: results.filter(result => result.passes).length, skipped: 0, failures,
    binarySha256: createHash('sha256').update(readFileSync(binary)).digest('hex'),
  };
  const file = resolve(root, 'catalog-audit.json');
  write(file, JSON.stringify(report, null, 2) + '\n');
  process.stdout.write(JSON.stringify({ ...report, reportFile: file }, null, 2) + '\n');
  return failures.length === 0 ? 0 : failures.some(result => result.stage !== 'lint' || result.status === 2 || result.error) ? 2 : 1;
};

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try { process.exitCode = main(); }
  catch (error) { process.stderr.write(`${String(error)}\n`); process.exitCode = 2; }
}
