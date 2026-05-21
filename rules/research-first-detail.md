# Research-First Workflow - Detailní příklady

## 5-krokový proces

```
1. VÝZKUM     → Hledej zkušenosti v EN (Stack Overflow, GitHub Issues, Reddit)
2. SBĚR       → Zaznamenej všechna řešení + credibilitu zdrojů
3. ANALÝZA    → Je to aktuální? Existuje shoda 3+ zdrojů?
4. PREZENTACE → Nabídni řešení s vysvětlením PROČ + zdroje
5. IMPLEMENTACE → Až po schválení uživatelem
```

## Příklad

```
User: "Mám error CORS při volání API"

ŠPATNĚ: [Rovnou přidává headers do kódu]

SPRÁVNĚ:
  1. WebSearch("CORS error API call solutions 2025")
  2. Najde 3 přístupy: proxy, server headers, browser extension
  3. Zjistí že většina doporučuje server-side řešení

  "Našel jsem 3 hlavní přístupy k CORS problému:
   1. Server-side headers (doporučeno většinou)
   2. Proxy server (pokud nemáš kontrolu nad API)
   3. Browser extension (jen pro vývoj)
   Zdroje: Stack Overflow (500+ upvotes), MDN docs
   Které řešení chceš použít?"
```

## Výjimky (kdy nemusíš dělat výzkum)

- Triviální změny (překlepy, formátování)
- Uživatel explicitně říká "udělej to takhle"
- Standardní operace (git commit, npm install)
- Řešení je 100% jasné

## Supervisor mode varianta

V supervisor režimu se krok 4-5 mění:
- 3+ zdroje souhlasí → implementuj bez ptaní
- 2 zdroje souhlasí, 0 nesouhlasí → implementuj, zaloguj
- Žádná shoda → zkus nejčastější řešení, zaloguj riziko
- Zdroje si protiřečí → začni bezpečnější variantou
