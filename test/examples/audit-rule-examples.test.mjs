import test from 'node:test';
import assert from 'node:assert/strict';
import { assessLint, extractFiles, parsePage, safeSourcePath } from '../../scripts/examples/audit-rule-examples.mjs';

const page = (id, extra = '') => `# \`${id}\`

## Examples

\`\`\`rescript
let shared = 1
\`\`\`

### Incorrect

\`\`\`rescript
Console.log(shared)
\`\`\`

### Correct

\`\`\`rescript
let value = shared
\`\`\`

${extra}
## Configuration

\`\`\`json
{"rules":{"${id}":true},"maxNesting":2}
\`\`\`

## Later
This heading ends configuration.
`;

test('parses primary and named pairs through heading section boundaries', () => {
  const parsed = parsePage('no-console', page('no-console', `### Incorrect: aliases
\`\`\`rescript
Console.log("x")
\`\`\`
### Correct: aliases
\`\`\`rescript
let x = 1
\`\`\`
`));
  assert.deepEqual(parsed.map(pair => pair.scenario), ['primary', 'aliases']);
  assert.equal(parsed[0].incorrect[0], 'let shared = 1');
  assert.equal(parsed[1].correct[0], 'let shared = 1');
  assert.equal(parsed[0].config.maxNesting, 2);
});

test('rejects mismatched title, missing halves, and missing target configuration', () => {
  assert.throws(() => parsePage('no-console', page('other')), /Expected page title/);
  assert.throws(() => parsePage('no-console', page('no-console').replace('### Correct', '### Valid')), /Missing Correct/);
  assert.throws(() => parsePage('no-console', page('no-console').replace('"no-console":true', '"other":true')), /must set rules/);
});

test('keeps multiple explicitly named files and rejects unsafe paths', () => {
  const files = extractFiles([`// src/Foo.res\nlet value = 1`, `// src/Foo.resi\ntype t`]);
  assert.deepEqual(files.map(file => file.path), ['Foo.res', 'Foo.resi']);
  assert.equal(safeSourcePath('src/nested/Foo.res'), 'nested/Foo.res');
  for (const unsafe of ['../outside.res', 'src/../../outside.res', '/tmp/a.res', 'C:\\a.res']) {
    assert.throws(() => safeSourcePath(unsafe), /Unsafe fixture path/);
  }
});

test('requires a matching incorrect/correct pair and configuration', () => {
  const mismatch = page('no-console').replace('### Correct', '### Correct: unrelated');
  assert.throws(() => parsePage('no-console', mismatch), /Missing Correct/);
  assert.throws(() => parsePage('no-console', page('no-console').replace('## Configuration', '## Options')), /Missing ## Configuration/);
});

test('preserves namespace IDs and raw configuration for runtime validation', () => {
  const [pair] = parsePage('react/jsx-key', page('react/jsx-key'));
  assert.equal(pair.id, 'react/jsx-key');
  assert.match(pair.configSource, /"react\/jsx-key":true/);
  assert.throws(() => parsePage('../README', page('../README')), /Invalid rule ID/);
  assert.throws(() => parsePage('no-console', page('no-console').replace(':true', ':false')), /must set rules/);
});

test('ignores headings inside fences and rejects duplicate or unclosed examples', () => {
  const text = page('no-console').replace('Console.log(shared)', '### Correct: not a heading\nConsole.log(shared)');
  assert.equal(parsePage('no-console', text).length, 1);
  const duplicate = page('no-console', '### Incorrect\n```rescript\nConsole.log(1)\n```\n');
  assert.throws(() => parsePage('no-console', duplicate), /Duplicate Incorrect/);
  assert.throws(() => parsePage('no-console', page('no-console') + '\n```rescript\n'), /Unclosed/);
});

test('combines anonymous setup but preserves named project files across fences', () => {
  assert.deepEqual(extractFiles(['let shared = 1', 'let next = shared']), [
    { path: 'Example.res', text: 'let shared = 1\n\nlet next = shared\n' },
  ]);
  const files = extractFiles(['// src/Metrics.res: exported declaration\nlet value = 1', '// src/Main.res\nlet main = () => Metrics.value']);
  assert.deepEqual(files.map(file => file.path), ['Metrics.res', 'Main.res']);
  assert.throws(() => extractFiles(['// src/Foo.res\nlet value = 1', '// src/Foo.res\nlet value = 2']), /Duplicate source filename/);
  assert.throws(() => extractFiles(['// src/../Outside.res\nlet value = 1']), /Unsafe fixture path/);
});

test('counts a multi-file incorrect case only when its target rule is reported', () => {
  const result = (status, diagnostics, errors = []) => ({
    status, stdout: JSON.stringify({ diagnostics, errors }), output: '',
  });
  assert.equal(assessLint('no-console', 'Incorrect', result(1, [{ rule: 'no-console' }])).passes, true);
  assert.equal(assessLint('no-console', 'Correct', result(0, [])).passes, true);
  assert.equal(assessLint('no-console', 'Incorrect', result(0, [])).passes, false);
  assert.equal(assessLint('no-console', 'Incorrect', result(1, [{ rule: 'other' }])).passes, false);
  assert.equal(assessLint('no-console', 'Correct', result(2, [], [{ kind: 'analysis' }])).passes, false);
  for (const stdout of ['null', '{}', 'not json']) {
    assert.equal(assessLint('no-console', 'Correct', { status: 0, stdout, output: stdout }).passes, false);
  }
});
