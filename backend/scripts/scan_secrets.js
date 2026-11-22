// =============================================================================
// Automated Secret & Credential Scanner (Prompt 19 Deliverable 3)
// Scans entire workspace for accidentally committed private keys, API secrets,
// database passwords, and cloud credentials using comprehensive regex patterns.
// =============================================================================

const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '../../');

const EXCLUDED_DIRS = new Set([
  'node_modules',
  '.git',
  '.dart_tool',
  'build',
  '.gradle',
  '.idea',
  'android/.gradle',
  'android/app/build',
  'ios/Pods',
  'temp_storage',
]);

const EXCLUDED_FILES = new Set([
  '.env.example',
  'package-lock.json',
  'pubspec.lock',
  'scan_secrets.js', // self
]);

const SECRET_PATTERNS = [
  {
    name: 'AWS Access Key ID',
    regex: /(?:A3T[A-Z0-9]|AKIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[A-Z0-9]{16}/,
  },
  {
    name: 'AWS Secret Access Key',
    regex: /(?:aws_secret_access_key|aws_secret_key)\s*[:=]\s*['"][A-Za-z0-9/+=]{40}['"]/i,
  },
  {
    name: 'RSA / OpenSSH / EC Private Key',
    regex: /-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----/,
  },
  {
    name: 'Google Service Account Private Key',
    regex: /"private_key"\s*:\s*"-----BEGIN PRIVATE KEY-----/,
  },
  {
    name: 'Xendit Live Secret Key',
    regex: /xnd_production_[a-zA-Z0-9_]{20,}/,
  },
  {
    name: 'GitHub Personal Access Token',
    regex: /gh[pousr]_[A-Za-z0-9_]{36,}/,
  },
  {
    name: 'Slack Token',
    regex: /xox[baprs]-[0-9a-zA-Z]{10,48}/,
  },
  {
    name: 'Hardcoded Production Database URL with Password',
    regex: /postgres(?:ql)?:\/\/[a-zA-Z0-9_]+:(?!postgres|password|admin|test)[a-zA-Z0-9!@#$%^&*()_+=-]+@[a-zA-Z0-9.-]+:[0-9]+\/[a-zA-Z0-9_]+/i,
  },
];

const findings = [];

const walkDir = (dir) => {
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relPath = path.relative(ROOT_DIR, fullPath);

    if (entry.isDirectory()) {
      if (EXCLUDED_DIRS.has(entry.name) || entry.name.startsWith('.')) {
        continue;
      }
      walkDir(fullPath);
    } else if (entry.isFile()) {
      if (EXCLUDED_FILES.has(entry.name)) {
        continue;
      }

      // Skip large binary files (> 2 MB)
      const stats = fs.statSync(fullPath);
      if (stats.size > 2 * 1024 * 1024) continue;

      try {
        const content = fs.readFileSync(fullPath, 'utf8');
        const lines = content.split('\n');

        lines.forEach((line, idx) => {
          for (const pattern of SECRET_PATTERNS) {
            if (pattern.regex.test(line)) {
              // Ignore matches in test files that clearly use mock / fake credentials
              if (
                relPath.includes('test') &&
                (line.includes('test_') || line.includes('mock') || line.includes('fake'))
              ) {
                continue;
              }

              findings.push({
                file: relPath,
                line: idx + 1,
                rule: pattern.name,
                snippet: line.trim().substring(0, 100),
              });
            }
          }
        });
      } catch {
        // Binary or unreadable file
      }
    }
  }
};

console.log('🔍 Memulai pemindaian rahasia di seluruh repositori...');
walkDir(ROOT_DIR);

console.log('\n============================================================');
console.log(`HASIL PEMINDAIAN RAHASIA (SECRET SCAN)`);
console.log('============================================================');

if (findings.length === 0) {
  console.log('✅ BERSIH: Tidak ditemukan kredensial rahasia, kunci privat, atau token bocor di kode sumber!');
} else {
  console.log(`⚠️ PERINGATAN: Ditemukan ${findings.length} potensi temuan rahasia:`);
  findings.forEach((f, i) => {
    console.log(`[${i + 1}] ${f.rule} di ${f.file}:${f.line}`);
    console.log(`    Cuplikan: ${f.snippet}\n`);
  });
}

// Export for programmatic test execution
module.exports = {
  scanSecrets: () => {
    findings.length = 0;
    walkDir(ROOT_DIR);
    return findings;
  },
};
