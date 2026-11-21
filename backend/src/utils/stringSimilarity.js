// =============================================================================
// String Similarity Utility (Name Match Review for Admin)
// =============================================================================
// Computes simple string similarity between user's registered name and bank account holder name.
// Non-blocking: Used for admin review guidance, does not prevent submission.

/**
 * Normalizes name by trimming, lowercasing, and removing common Indonesian academic titles/honorifics.
 */
const normalizeName = (name) => {
  if (!name || typeof name !== 'string') return '';
  return name
    .toLowerCase()
    .replace(/\b(s\.?kom|s\.?e|s\.?t|s\.?h|s\.?pd|m\.?m|m\.?kom|dr|dra|drs|ir|h|hj)\b/gi, '')
    .replace(/[^a-z0-9\s]/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
};

/**
 * Calculates Levenshtein distance between two strings.
 */
const levenshteinDistance = (str1, str2) => {
  const m = str1.length;
  const n = str2.length;
  const dp = Array.from({ length: m + 1 }, () => Array(n + 1).fill(0));

  for (let i = 0; i <= m; i++) dp[i][0] = i;
  for (let j = 0; j <= n; j++) dp[0][j] = j;

  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      if (str1[i - 1] === str2[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1];
      } else {
        dp[i][j] = 1 + Math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
      }
    }
  }

  return dp[m][n];
};

/**
 * Computes a similarity score between 0.0 and 1.0.
 * Combines token overlap and edit distance.
 *
 * @param {string} nameA
 * @param {string} nameB
 * @returns {{ score: number, confidence: 'HIGH'|'MEDIUM'|'LOW' }}
 */
const calculateNameMatch = (nameA, nameB) => {
  const normA = normalizeName(nameA);
  const normB = normalizeName(nameB);

  if (!normA || !normB) {
    return { score: 0, confidence: 'LOW' };
  }

  if (normA === normB) {
    return { score: 1.0, confidence: 'HIGH' };
  }

  // Token overlap (Jaccard on words)
  const tokensA = new Set(normA.split(' ').filter(Boolean));
  const tokensB = new Set(normB.split(' ').filter(Boolean));
  const intersection = [...tokensA].filter((t) => tokensB.has(t));
  const union = new Set([...tokensA, ...tokensB]);
  const tokenScore = union.size > 0 ? intersection.length / union.size : 0;

  // Character edit distance
  const maxLen = Math.max(normA.length, normB.length);
  const editDist = levenshteinDistance(normA, normB);
  const charScore = maxLen > 0 ? Math.max(0, (maxLen - editDist) / maxLen) : 0;

  // Weighted score
  const score = Math.round((0.5 * tokenScore + 0.5 * charScore) * 100) / 100;

  let confidence = 'LOW';
  if (score >= 0.75) {
    confidence = 'HIGH';
  } else if (score >= 0.45) {
    confidence = 'MEDIUM';
  }

  return { score, confidence };
};

module.exports = {
  normalizeName,
  calculateNameMatch,
};
