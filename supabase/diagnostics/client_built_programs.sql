-- Προγράμματα από το «Φτιάχνω δικό μου πρόγραμμα»: ΜΟΝΟ πλήθος και ώρα (χωρίς πελάτες/ονόματα)
select count(*) as programs, max(created_at) as latest
from public.programs where days->>'fromClientBuilder' = 'true'
