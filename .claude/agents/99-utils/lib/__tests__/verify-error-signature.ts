#!/usr/bin/env ts-node
/**
 * error-signature 함수 검증 스크립트
 *
 * Jest가 없는 환경에서도 기본 동작을 확인할 수 있도록
 * 간단한 assertion 로직을 구현합니다.
 */

import {
  generateErrorSignature,
  extractKeywords,
  normalizeErrorType,
} from '../error-signature';

function assert(condition: boolean, message: string) {
  if (!condition) {
    console.error(`❌ FAIL: ${message}`);
    process.exit(1);
  }
  console.log(`✅ PASS: ${message}`);
}

function assertEqual(actual: any, expected: any, testName: string) {
  const actualStr = JSON.stringify(actual);
  const expectedStr = JSON.stringify(expected);
  if (actualStr !== expectedStr) {
    console.error(`❌ FAIL: ${testName}`);
    console.error(`  Expected: ${expectedStr}`);
    console.error(`  Actual: ${actualStr}`);
    process.exit(1);
  }
  console.log(`✅ PASS: ${testName}`);
}

console.log('🧪 Testing error-signature functions...\n');

// ===== normalizeErrorType =====
console.log('📝 normalizeErrorType Tests:');
assertEqual(
  normalizeErrorType('Error: 405 Method Not Allowed'),
  '405 Method Not Allowed',
  'Remove Error prefix'
);
assertEqual(
  normalizeErrorType("TypeError: Cannot read property 'x' of undefined"),
  "Cannot read property 'x' of undefined",
  'Remove TypeError prefix'
);
assertEqual(
  normalizeErrorType('ReferenceError: foo is not defined'),
  'foo is not defined',
  'Remove ReferenceError prefix'
);
assertEqual(
  normalizeErrorType('Connection timeout'),
  'Connection timeout',
  'Handle strings without Error prefix'
);

// ===== extractKeywords =====
console.log('\n📝 extractKeywords Tests:');
const keywords1 = extractKeywords('405 Method Not Allowed', 'app/api/route.ts');
assert(keywords1.includes('405'), 'Extract 405 error code');
assert(keywords1.includes('메서드 누락'), 'Extract method missing keyword');

const keywords2 = extractKeywords('Some error', 'apps/frontend/src/app/api/users/route.ts');
assert(keywords2.includes('API Routes'), 'Extract API Routes from file path');

const keywords3 = extractKeywords('DELETE Method Not Allowed', 'route.ts');
assert(keywords3.includes('DELETE 메서드'), 'Extract DELETE method');

const keywords4 = extractKeywords('useEffect 무한 루프 발생', 'Component.tsx');
assert(keywords4.includes('React Hook'), 'Extract React Hook keyword');
assert(keywords4.includes('무한 루프'), 'Extract infinite loop keyword');

// ===== generateErrorSignature (Task 요구사항) =====
console.log('\n📝 generateErrorSignature Tests (Task Requirements):');
assertEqual(
  generateErrorSignature('405 Method Not Allowed', ['DELETE 메서드']),
  '405-method-not-allowed-delete-메서드',
  'Task Case 1: 405 with DELETE'
);

assertEqual(
  generateErrorSignature('404 Not Found', ['중첩 엔드포인트']),
  '404-not-found-중첩-엔드포인트',
  'Task Case 2: 404 with nested endpoint'
);

assertEqual(
  generateErrorSignature('Infinite Loop', ['useEffect', 'dependencies']),
  'infinite-loop-useeffect-dependencies',
  'Task Case 3: Infinite loop with useEffect'
);

// ===== 추가 테스트 =====
console.log('\n📝 generateErrorSignature Additional Tests:');
assertEqual(
  generateErrorSignature('Error: Connection Failed!!!', ['DB 연결', 'CORS']),
  'connection-failed-db-연결-cors',
  'Handle special characters'
);

assertEqual(
  generateErrorSignature('Error!!!  Multiple  Spaces', ['Test---Keyword']),
  'multiple-spaces-test-keyword',
  'Normalize consecutive hyphens'
);

assertEqual(
  generateErrorSignature('404 Not Found', []),
  '404-not-found',
  'Handle empty keywords array'
);

assertEqual(
  generateErrorSignature('API Error', ['인증 실패', 'Token', '만료']),
  'api-error-인증-실패-token-만료',
  'Handle mixed English and Korean keywords'
);

console.log('\n🎉 All tests passed!');
