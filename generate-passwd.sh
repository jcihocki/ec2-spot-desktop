#!/usr/bin/node

process.stdout.write(require('crypto').randomBytes(18).toString('base64'));

