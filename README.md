# 80 Procent

Bar-widget voor [Omarchy](https://omarchy.org) die de acculimiet van een Intel-MacBook schakelt tussen vol laden en stoppen bij 80%. De limiet staat in de Apple-SMC (BCLM/BFCL) en overleeft een herstart.

> **Status: experimenteel.** De widget is klein en getest op één Intel-MacBook, maar de setuid-root helper en de SMC-schrijfwijze vragen om voorzichtigheid. Lees de installatiestappen voordat je hem op je eigen machine zet.

- Linkerklik op het accu-icoon: schakelen tussen 80% en vol.
- Rechterklik: accustatus, lader en de huidige limiet.
- Het icoon laat zien of de limiet actief is.

## Vereisten

- Een Intel-MacBook met Linux en de `applesmc`-driver.
- Omarchy met de Quickshell-shell (`omarchy-shell`), plus `jq`.
- `gcc` en `make` om de meegeleverde helper te bouwen.

## Downloaden en installeren

```sh
git clone https://github.com/michielturmel-max/80procent.git
cd 80procent
```

De widget schrijft de SMC via een kleine setuid-root helper. Installeer die eenmalig:

```sh
make -C tool
sudo install -m 4755 -o root -g root tool/macbook-charge-limit /usr/local/bin/macbook-charge-limit
```

Daarna de plugin zelf:

```sh
./install.sh install
```

Staat de widget nog niet in de balk, herstart dan de shell of zet hem aan:

```sh
omarchy-restart-shell
# of:
omarchy plugin enable 80procent
```

`./install.sh helper` laat zien welke regel je voor de helper moet uitvoeren. `./install.sh version` toont de versie en `./install.sh uninstall` verwijdert de plugin; de SMC-limiet blijft daarbij staan (terugzetten kan met `sudo macbook-charge-limit reset`). Wil je ook de helper zelf weghalen:

```sh
sudo rm /usr/local/bin/macbook-charge-limit
```

## Bediening

| Actie | Wat het doet |
| --- | --- |
| linksklik | schakel tussen 80% en vol laden |
| rechtsklik | toon de accustatus |
| middenklik | ververs de status |
| `enter` | schakelen |
| `r` | verversen |
| `esc` | paneel sluiten |

## Hoe het werkt

`bin/laadlimiet` leest de accu uit `/sys/class/power_supply` en praat met `macbook-charge-limit`, een kleine C-helper die alleen de SMC-sleutels BCLM en BFCL mag schrijven, met een waarde tussen 20 en 100, en uitsluitend op Apple-hardware. De plugin kopieert die helper niet zelf naar `/usr/local/bin`; dat is de enige stap die sudo vraagt.

De helper in `tool/` is gebaseerd op [macbook-charge-limit](https://github.com/jordanbrough/macbook-charge-limit) van Jordan Brough en valt onder de MIT-licentie in [`tool/LICENSE`](tool/LICENSE).

## Ontwikkelen

```sh
make -C tool            # helper bouwen
./install.sh install    # plugin installeren en de shell laten herscannen
omarchy plugin validate .
```

## Licentie

MIT, zie [LICENSE](LICENSE).
