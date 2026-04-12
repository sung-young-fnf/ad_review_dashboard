export default function Home() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="text-center space-y-4">
        <h1 className="text-3xl font-bold">{{APP_NAME}}</h1>
        <p className="text-gray-500">앱이 정상 실행 중입니다.</p>
      </div>
    </div>
  );
}
