export function BackendErrorMessage({ message }: { message: string }) {
  return (
    <div className="flex items-center justify-center min-h-[50vh]">
      <div className="max-w-md p-6 rounded-lg border border-red-300 bg-red-50 dark:border-red-800 dark:bg-red-950">
        <h2 className="text-lg font-semibold text-red-800 dark:text-red-200 mb-2">
          Backend Unavailable
        </h2>
        <p className="text-sm text-red-700 dark:text-red-300 mb-4">{message}</p>
        <p className="text-xs text-red-600 dark:text-red-400">
          Make sure PocketBase is running:{" "}
          <code className="bg-red-100 dark:bg-red-900 px-1.5 py-0.5 rounded">
            ./pocketbase serve --http 0.0.0.0:8090
          </code>
        </p>
      </div>
    </div>
  );
}
