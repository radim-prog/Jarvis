# Zachování kontextu důležitých konverzací

Když uživatel dá **10+ řádkové detailní zadání**, popíše důležité rozhodnutí, vysvětlí kontext nebo specifikuje požadavky na funkcionalitu → VŽDY vytvoř soubor:

```
.claude-context/YYYY-MM-DD-nazev-temy.md
```

## Formát souboru

```markdown
# [Název tématu]
**Datum:** YYYY-MM-DD
**Kategorie:** [funkcionalita|design|architektura|business]

## Původní zadání uživatele
[Doslovná citace nebo pečlivé shrnutí]

## Klíčová rozhodnutí
- Rozhodnutí 1
- Rozhodnutí 2

## Důvody a kontext
Proč bylo toto rozhodnuto...

## Akční body
- [ ] Co bylo implementováno
- [ ] Co zbývá udělat
```

## Pravidla

- Před začátkem práce na projektu: zkontroluj jestli existuje `.claude-context/`, pokud ne, vytvoř
- Přečti si poslední soubory v `.claude-context/` pro kontext projektu
- Kontextové soubory jsou READ-ONLY reference - neměň staré, přidávej nové
