-- Bandeira/forma fina do pagamento no MP Point (payment_method_id): visa,
-- master, elo, alelo, sodexo, vr, ticket… Nulo = ainda não conhecida (pendente
-- ou pagamento sem detalhe do MP). Complementa `tipo` (credito|debito|voucher).
ALTER TABLE "point_payments" ADD COLUMN "bandeira" TEXT;
