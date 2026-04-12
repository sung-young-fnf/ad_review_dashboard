/**
 * error-signature 생성 유틸리티
 *
 * 에러를 고유하게 식별할 수 있는 signature를 생성합니다.
 * - 에러 타입과 키워드를 조합하여 normalized string 생성
 * - 한글 키워드 지원
 * - 특수문자는 하이픈으로 변환
 */

/**
 * 에러 타입을 정규화합니다.
 *
 * @example
 * normalizeErrorType("Error: 405 Method Not Allowed")
 * // => "405 Method Not Allowed"
 *
 * @example
 * normalizeErrorType("TypeError: Cannot read property 'x' of undefined")
 * // => "Cannot read property 'x' of undefined"
 */
export function normalizeErrorType(errorType: string): string {
  // 콜론이 있거나 없는 경우 모두 처리 (예: "Error: " 또는 "Error!!!")
  return errorType.replace(/^(Error|TypeError|ReferenceError):?\s*/, '').trim();
}

/**
 * 에러 메시지와 파일 경로에서 키워드를 자동 추출합니다.
 *
 * @example
 * extractKeywords("405 Method Not Allowed", "apps/frontend/src/app/api/route.ts")
 * // => ["405", "DELETE 메서드", "API Routes"]
 */
export function extractKeywords(errorMessage: string, filePath: string): string[] {
  const keywords: string[] = [];

  // HTTP 에러 코드
  if (/405/.test(errorMessage)) keywords.push('405');
  if (/404/.test(errorMessage)) keywords.push('404');
  if (/500/.test(errorMessage)) keywords.push('500');
  if (/401/.test(errorMessage)) keywords.push('401');
  if (/403/.test(errorMessage)) keywords.push('403');

  // Next.js API Routes
  if (/api.*route\.ts/.test(filePath)) keywords.push('API Routes');

  // 메서드 관련
  if (/DELETE/i.test(errorMessage)) keywords.push('DELETE 메서드');
  if (/POST/i.test(errorMessage)) keywords.push('POST 메서드');
  if (/PUT/i.test(errorMessage)) keywords.push('PUT 메서드');
  if (/GET/i.test(errorMessage)) keywords.push('GET 메서드');

  if (/메서드.*누락|Method.*Not.*Allowed/i.test(errorMessage)) {
    keywords.push('메서드 누락');
  }

  // React Hooks
  if (/useEffect/i.test(errorMessage)) keywords.push('React Hook');
  if (/무한.*루프|infinite.*loop/i.test(errorMessage)) keywords.push('무한 루프');
  if (/dependencies|의존성/.test(errorMessage)) keywords.push('dependencies');

  // 데이터베이스
  if (/database|db|postgres|prisma/i.test(errorMessage)) keywords.push('Database');
  if (/connection|연결/i.test(errorMessage)) keywords.push('Connection');

  // CORS
  if (/cors/i.test(errorMessage)) keywords.push('CORS');

  return keywords;
}

/**
 * 에러를 고유하게 식별할 수 있는 error-signature를 생성합니다.
 *
 * @param errorType - 에러 타입 (예: "405 Method Not Allowed")
 * @param keywords - 추출된 키워드 배열
 * @returns normalized signature (예: "405-method-not-allowed-delete-메서드")
 *
 * @example
 * generateErrorSignature("405 Method Not Allowed", ["DELETE 메서드", "API Routes"])
 * // => "405-method-not-allowed-delete-메서드-api-routes"
 *
 * @example
 * generateErrorSignature("Infinite Loop", ["useEffect", "dependencies"])
 * // => "infinite-loop-useeffect-dependencies"
 */
export function generateErrorSignature(errorType: string, keywords: string[]): string {
  // 에러 타입 정규화
  const normalized = normalizeErrorType(errorType);

  // 모든 문자열 조합
  const combined = [normalized, ...keywords].join('-');

  // 정규화
  // 1. 소문자 변환
  // 2. 특수문자를 하이픈으로 변환 (단, 한글/영문/숫자/하이픈만 유지)
  // 3. 연속된 하이픈을 하나로 축약
  // 4. 앞뒤 하이픈 제거
  const signature = combined
    .toLowerCase()
    .replace(/[^a-z0-9가-힣-]/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '');

  return signature;
}
