import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import App from '@/App';

describe('App (smoke)', () => {
  it('renderiza a tela de login com a marca GoGeM', () => {
    // Rota pública, sem token → App deve mostrar o login.
    window.history.pushState({}, '', '/login');

    render(<App />);

    // Wordmark da marca (span com aria-label="GoGeM").
    expect(screen.getByLabelText('GoGeM')).toBeInTheDocument();
    // Título da tela de login.
    expect(
      screen.getByRole('heading', { name: 'Entrar' }),
    ).toBeInTheDocument();
  });
});
