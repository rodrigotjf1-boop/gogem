import { QueryClient } from '@tanstack/react-query';

/** QueryClient configurado para o backoffice. */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
      staleTime: 30_000,
    },
  },
});
