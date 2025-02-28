# ReScript Lint
Linting for [ReScript](https://rescript-lang.org/) built with [ast-grep](https://ast-grep.github.io/).

## ALPHA
This is in the early stages of development. Rules are limited and it might not work 100% as expected. Issues and PRs are welcome!

## Installation
Rescript Lint requires Node 22+ and is recommended to use with ESM. It has not been tested with CJS and it isn't supported officially.
### Install the package
```
npm i rescript-lint -D
```
### Create a config file
```
// rescript-lint.mjs
export default {
    "include": ["src"], // Glob of files to include or exclude
    "rules": {
        "no-console": "error" // error, warning, off
    }
}
```

### Run the setup command
ReScript lint is using ast-grep under the hood, so we need to run a command to configure it anytime you change the config file.
```
npm exec rescrip-lint:init
```

### ast-grep VSCode extension
There is an ast-grep [VSCode extension](https://marketplace.visualstudio.com/items?itemName=ast-grep.ast-grep-vscode#overview) you can install to highlight errors and warnings.
The init command will make sure you have the `.vscode/settings.json` configured. If you want to manually configure or change it just make sure you have `"astGrep.configPath": "node_modules/rescript-lint/sgconfig.yml"` set.

ast-grep [supports other editors](https://ast-grep.github.io/guide/tools/editors.html), just make sure you have the config path set to `node_modules/rescript-lint/sgconfig.yml`.
