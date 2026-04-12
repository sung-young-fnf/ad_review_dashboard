import {
  generateErrorSignature,
  extractKeywords,
  normalizeErrorType,
} from '../error-signature';

describe('normalizeErrorType', () => {
  it('should remove Error prefix', () => {
    expect(normalizeErrorType('Error: 405 Method Not Allowed')).toBe('405 Method Not Allowed');
  });

  it('should remove TypeError prefix', () => {
    expect(normalizeErrorType("TypeError: Cannot read property 'x' of undefined")).toBe(
      "Cannot read property 'x' of undefined"
    );
  });

  it('should remove ReferenceError prefix', () => {
    expect(normalizeErrorType('ReferenceError: foo is not defined')).toBe('foo is not defined');
  });

  it('should handle strings without Error prefix', () => {
    expect(normalizeErrorType('Connection timeout')).toBe('Connection timeout');
  });

  it('should trim whitespace', () => {
    expect(normalizeErrorType('Error:   Multiple  Spaces  ')).toBe('Multiple  Spaces');
  });
});

describe('extractKeywords', () => {
  it('should extract 405 error code', () => {
    const keywords = extractKeywords('405 Method Not Allowed', 'app/api/route.ts');
    expect(keywords).toContain('405');
  });

  it('should extract API Routes from file path', () => {
    const keywords = extractKeywords('Some error', 'apps/frontend/src/app/api/users/route.ts');
    expect(keywords).toContain('API Routes');
  });

  it('should extract DELETE method', () => {
    const keywords = extractKeywords('DELETE Method Not Allowed', 'route.ts');
    expect(keywords).toContain('DELETE 메서드');
  });

  it('should extract method missing keyword', () => {
    const keywords = extractKeywords('메서드가 누락되었습니다', 'route.ts');
    expect(keywords).toContain('메서드 누락');
  });

  it('should extract React Hook keywords', () => {
    const keywords = extractKeywords('useEffect 무한 루프 발생', 'Component.tsx');
    expect(keywords).toContain('React Hook');
    expect(keywords).toContain('무한 루프');
  });

  it('should extract database keywords', () => {
    const keywords = extractKeywords('Prisma connection error', 'database.ts');
    expect(keywords).toContain('Database');
    expect(keywords).toContain('Connection');
  });

  it('should handle multiple HTTP codes', () => {
    const keywords = extractKeywords('404 or 500 error', 'api.ts');
    expect(keywords).toContain('404');
    expect(keywords).toContain('500');
  });
});

describe('generateErrorSignature', () => {
  // Task 요구사항 테스트 케이스
  it('should generate signature for 405 Method Not Allowed with DELETE', () => {
    const signature = generateErrorSignature('405 Method Not Allowed', ['DELETE 메서드']);
    expect(signature).toBe('405-method-not-allowed-delete-메서드');
  });

  it('should generate signature for 404 Not Found with nested endpoint', () => {
    const signature = generateErrorSignature('404 Not Found', ['중첩 엔드포인트']);
    expect(signature).toBe('404-not-found-중첩-엔드포인트');
  });

  it('should generate signature for infinite loop with useEffect', () => {
    const signature = generateErrorSignature('Infinite Loop', ['useEffect', 'dependencies']);
    expect(signature).toBe('infinite-loop-useeffect-dependencies');
  });

  // 추가 테스트 케이스
  it('should handle special characters', () => {
    const signature = generateErrorSignature('Error: Connection Failed!!!', [
      'DB 연결',
      'CORS',
    ]);
    expect(signature).toBe('connection-failed-db-연결-cors');
  });

  it('should normalize consecutive hyphens', () => {
    const signature = generateErrorSignature('Error!!!  Multiple  Spaces', ['Test---Keyword']);
    expect(signature).toBe('multiple-spaces-test-keyword');
  });

  it('should handle empty keywords array', () => {
    const signature = generateErrorSignature('404 Not Found', []);
    expect(signature).toBe('404-not-found');
  });

  it('should remove Error prefix before generating signature', () => {
    const signature = generateErrorSignature('Error: 500 Internal Server Error', ['Backend']);
    expect(signature).toBe('500-internal-server-error-backend');
  });

  it('should handle mixed English and Korean keywords', () => {
    const signature = generateErrorSignature('API Error', ['인증 실패', 'Token', '만료']);
    expect(signature).toBe('api-error-인증-실패-token-만료');
  });

  it('should normalize parentheses and brackets', () => {
    const signature = generateErrorSignature('Type Error (foo.bar)', ['undefined', 'null']);
    expect(signature).toBe('type-error-foo-bar-undefined-null');
  });

  it('should handle leading and trailing hyphens', () => {
    const signature = generateErrorSignature('---Error---', ['---Keyword---']);
    expect(signature).toBe('error-keyword');
  });
});
