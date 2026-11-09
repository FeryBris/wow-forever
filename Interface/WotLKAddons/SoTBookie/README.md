# SoTBookie v1.0.0

Guildovni sazkova tabule pro WoW 3.3.5a (Warmane). Vypis sazku, vyber si
stranu, vyrovnejte se.

Nekdo vypise sazku ("Priste na tom pullu wipneme") s vkladem (treba 300g).
Kazdy s addonem si jednim klikem vybere stranu - ANO (souhlasi) nebo NE -
dokud autor sazku nezamkne. Az se to rozhodne, autor vyhlasi vitezstvi;
vklady porazenych se slozi do banku, rozdeli mezi viteze a SoTBookie vsem ukaze
stejny platebni plan (kdo komu kolik). Zlato si predavate postaru pres trade
okno - SoTBookie jen vede skore, historii a guildovni zebricek.

## Instalace

1. Sezen si slozku `SoTBookie` (zip z guild launcheru nebo od Blueblacka).
2. Rozbal ji do `<WoW>\Interface\AddOns\`, takze vznikne
   `Interface\AddOns\SoTBookie\SoTBookie.toc`.
3. **Uplne vypni a zapni hru** (novy addon se nacita jen pri startu klienta,
   /reload nestaci). Hotovo - `/bet` otevre tabuli.

Funguje stejne na Windows, wine/Linux i macu - nic se neinstaluje mimo tuhle
slozku.

## Ovladani

- **`/bet`** (nebo mince u minimapy) otevre okno. Karty: Aktivni, Historie,
  Dluhy, Zebricek, Nastaveni.
- **Vypsat sazku**: napis text, nastav vklad, Vyhlasit. Automaticky stojis
  na strane ANO - svemu tvrzeni prece veris.
- **Vybrat stranu**: klik na ANO nebo NE u sazky. Klik na druhou stranu =
  prestup, klik na svou stranu = odchod. Jde to, jen dokud je sazka otevrena.
- **Zamek** (jen autor): ikona zamku zmrazi strany - klikni tesne pred
  pullem. Dalsi klik sazku zase odemkne, kdyz se jeste nekdo chce pridat.
- **Rozhodnout** (jen autor, u zamcene sazky): vyber vitezne strany. Pred
  potvrzenim vidis cely platebni plan a muzes zaskrtnout, ze se vysledek
  ohlasi do chatu. Zrusit sazku jde kdykoliv (krizek).
- **Dluhy**: spolecny prehled plateb. Dluznik klikne **Zaplaceno**, prijemce
  potvrdi **Prislo** - stav vidi cela guilda, takze se nikdo nemusi dohadovat,
  co uz je vyrovnane.
- **Zebricek**: ciste zlato, vyhry/prohry, nejvetsi vyhra.
- **Oznamit**: volitelna ikona, ktera posle JEDNU citelnou radku do
  raid/party/guild chatu. Sam od sebe SoTBookie do chatu nikdy nepise.

Vsechno ostatni je neviditelne: sazky cestuji skrytymi addon zpravami v
guild kanalu. Kdo addon nema, nevidi nic (dokud neklikne nekdo Oznamit).

## Domovni rad (precti jednou)

- **Je to hracka, ne kasino.** Vklady jsou vec tebe a tveho svedomi; SoTBookie
  ti zlato nikdy kontrolovat nebude.
- **Sazka o spoluhracovi?** ("X umre v ohni prvni") - pozvi ho do ni. Sazka
  o nekom je vtipnejsi S nim.
- **Slovo autora plati.** Historie si pamatuje, kdo a kdy rozhodl - hadejte
  se v guild chatu, ne v ticketech.
- **Jedna postava = jedna identita.** Sazky z altu se resi na altu.

## Zname zvlastnosti (vlastnosti 3.3.5, ne bugy)

- Kdyz tvuj guild rank nesmi cist guild chat, nechodi ti ani addon zpravy -
  neuvidis zadne sazky. SoTBookie te na to sam upozorni; popros officera.
- Kdyz si te nekdo da na ignore, tise mu nechodi tvoje sazky. Addon to nema
  jak poznat.
- Kdyz ti neco chybi, pouzij tlacitko **Nacist sazky od guildy** na karte
  Nastaveni - po prihlaseni ale probehne sync sam.
- Otevrene sazky, jejichz autor zmizel (3+ dny), samy vyprsi.
- Kdyz vyjde novejsi verze, SoTBookie ti to jednou za prihlaseni napise do
  chatu - novy zip bude v guild launcheru.
