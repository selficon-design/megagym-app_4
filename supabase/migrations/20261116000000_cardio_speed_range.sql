-- Αερόβια διαδρόμου χωρίς ταχύτητα: εύρος 3 έως 6 km/h (speedLow / speedLowMax)
update public.template_programs t
set data = jsonb_set(t.data, '{days}', (
  select jsonb_agg(
    case when jsonb_typeof(d->'items')='array' then jsonb_set(d, '{items}', (
      select jsonb_agg(
        case when i->>'type'='cardio' and i->>'equipment' in ('ΔΙΑΔΡΟΜΟΣ','Διάδρομος') and coalesce(i->>'speedLow','')='' and coalesce(i->>'speedLowMax','')=''
             then i || '{"speedLow":"3","speedLowMax":"6"}'::jsonb else i end order by io)
      from jsonb_array_elements(d->'items') with ordinality x(i, io)))
    else d end order by dno)
  from jsonb_array_elements(t.data->'days') with ordinality y(d, dno)))
where jsonb_typeof(t.data->'days')='array' and jsonb_array_length(t.data->'days')>0;

-- Ίδιο και στα προγράμματα πελατών που αντιγράφηκαν από έτοιμα (days.days[].cardioSlots[])
update public.programs p
set days = jsonb_set(p.days, '{days}', (
  select jsonb_agg(
    case when jsonb_typeof(d->'cardioSlots')='array' and jsonb_array_length(d->'cardioSlots')>0 then jsonb_set(d, '{cardioSlots}', (
      select jsonb_agg(
        case when c->>'equipment' in ('ΔΙΑΔΡΟΜΟΣ','Διάδρομος') and coalesce(c->>'speedLow','')='' and coalesce(c->>'speedLowMax','')=''
             then c || '{"speedLow":"3","speedLowMax":"6"}'::jsonb else c end order by co)
      from jsonb_array_elements(d->'cardioSlots') with ordinality x(c, co)))
    else d end order by dno)
  from jsonb_array_elements(p.days->'days') with ordinality y(d, dno)))
where jsonb_typeof(p.days)='object' and coalesce(p.days->>'fromTemplate','')='true'
  and jsonb_typeof(p.days->'days')='array' and jsonb_array_length(p.days->'days')>0;
