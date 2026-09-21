#!/usr/bin/env node
import { finish, launch } from "../lib/launcher.mjs";

finish(await launch(process));
