# Valencia heatwaves 2026: residential electricity

Code and data for the residential electricity section of *Attributing the
economic cost of the summer 2026 heat waves in València to climate change*
(Riffiod et al.).

The script estimates the additional air-conditioning consumption of the
city's primary dwellings caused by the warming attributable to climate change
during the three AEMET heatwaves of summer 2026 (20-27 June, 2-24 July,
28 July-20 August), and values it at the day-ahead spot price. Wave 4
(2-7 September) is excluded: AEMET classifies it as provisional and Barnes et
al. (2026) give no attributable warming for September.

## Method

For heatwave day *j* of month *m*, consumption is zero up to a threshold of
the daily maximum temperature (24 °C) and proportional to the degrees above
it:

    additional MWh_j = H x slope_m x [DD(Tmax_j) - DD(Tmax_j - delta_m)] / 1000
    DD(T) = max(T - 24, 0)

- **H = 268,335 equipped dwellings**: population 858,178 / 2.5 persons per
  household x 78.2% of primary dwellings with a cooling system (INE, ECEPOV
  2021, table 56804).
- **Slope**: cooling consumption measured by SPAHOUSEC III (IDAE 2026) in the
  primary dwellings of the Mediterranean zone in the same month of 2022,
  divided by the number of days, by the 7,983,178 equipped dwellings of the
  zone and by the mean degrees above 24 °C at station 8416 in that month.
- **delta_m**: warming attributable to climate change in València (city
  ES003C), Barnes et al. (2026).
- **Cost**: day-ahead spot price of the day (mean of the hourly prices),
  excluding taxes. The regulated household tariff (PVPC) before taxes is a
  sensitivity.

## Main results

| Wave | Days | Mean spot price (EUR/MWh) | Additional consumption (MWh) | Cost (EUR) | Cost with the bounds of delta (EUR) |
|---|---:|---:|---:|---:|---:|
| 1 (20-27 Jun) | 8 | 83.53 | 1,500 | 125,333 | 77,697-172,040 |
| 2 (2-24 Jul) | 23 | 105.58 | 4,718 | 498,116 | 298,278-695,027 |
| 3 (28 Jul-20 Aug) | 24 | 126.37 | 3,778 | 477,868 | 307,498-646,722 |
| Total | 55 | 111.44 | 9,997 | 1,101,317 | 683,473-1,513,789 |

The script prints every figure of sections 3.5 and 4.4 of the paper:
Table 4 (calibration), Table 10 (above), the three other calibrations of the
slope (daily mean with a 21 °C threshold, a line fitted on June-September
2022, a physical model), the 25 °C threshold, the PVPC tariff, and the share
of the city's household electricity use.

## Running the code

Requirements: R, base packages only (results above obtained with R 4.4.3).
Open `valencia_heatwave_electricity.Rproj` (or set the working directory to
the repository root) and run

```r
source("electricity.R")
```

Results are printed and written to `output/`. The script reads only the files
in `data/`; nothing is downloaded.

## Data

| File | Content | Source |
|---|---|---|
| `aemet_8416_daily_jun-sep_2016-2026.csv` | Daily mean and maximum temperature, June-September 2016-2026, with the station code of each day | AEMET OpenData, daily climatological values, station València 8416 (code 8416Y, occasionally 8416X, before 2026; 8416 in 2026) |
| `ree_daily_prices_jun-aug_2026.csv` | Daily day-ahead spot price (mean of hourly prices) and PVPC price before taxes, EUR/MWh | Red Eléctrica de España, REData API (`precios-mercados-tiempo-real`) |
| `delta_barnes_2026_valencia.csv` | Monthly attributable warming for València (city ES003C), central value and 95% bounds | Barnes et al. (2026), data and code, doi:10.5281/zenodo.22228326 |
| `heatwaves_aemet_2026.csv` | Dates and status of the 2026 heatwaves | AEMET, note of 9 September 2026 |

Parameters taken from publications are set at the top of `electricity.R`
with their source:

- population: Ajuntament de València, provisional municipal register at
  1 January 2026 (note of 9 May 2026);
- persons per household: province of València, 2025 (2,766,375 inhabitants
  / 1,104,496 households, *Mercado Inmobiliario de Valencia*, 2nd quarter
  2025);
- cooling consumption and equipped dwellings: IDAE (2026), SPAHOUSEC III,
  results files 34 and 04;
- household electricity use: Ajuntament de València, indicator 06153310
  (from Iberdrola), 2023.

## Limitations

The slope comes from one year of measurements for the whole Mediterranean
zone. The estimate covers primary dwellings only and holds the stock of air
conditioners fixed; it is a lower bound. The threshold of 24 °C is an
assumption (25 °C raises the cost by 16%). The physical model (method C)
relies on two weakly sourced values (share of the dwelling cooled,
frigories per m²); it is used for comparison only.

## References

AEMET (2026). Olas de calor 2026. Note of 9 September 2026.
https://www.aemet.es/es/noticias/2026/09/olas_de_calor_2026

Barnes, C. et al. (2026). Data and code. Zenodo.
https://doi.org/10.5281/zenodo.22228326

IDAE (2026). SPAHOUSEC III: Estudio del consumo energético, equipamiento y
hábitos de consumo de la energía del sector residencial en España. Instituto
para la Diversificación y Ahorro de la Energía, NIPO 629-26-001-8.
https://informesweb.idae.es/spahousec-iii/index.php

INE. Encuesta de Características Esenciales de la Población y las Viviendas
(ECEPOV) 2021, table 56804.

Valor, E., Meneu, V., Caselles, V. (2001). Daily air temperature and
electricity load in Spain. *Journal of Applied Meteorology* 40(8), 1413-1421.
https://doi.org/10.1175/1520-0450(2001)040<1413:DATAEL>2.0.CO;2

Viegand Maagøe, ARMINES (2018). Review study of Commission Regulation (EU)
No 206/2012 (air conditioners and comfort fans), Task 2.

## Licence

MIT. See `LICENSE`.
