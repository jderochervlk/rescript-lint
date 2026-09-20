#!/usr/bin/env node
"use strict";

const { launch, finish } = require("../lib/launcher.cjs");

launch(process).then((result) => finish(result));
