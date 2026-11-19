# Residential air-conditioning cost of the 2026 heatwaves attributable to
# climate change, city of Valencia (section 3.5 and 4.4 of the paper).
#
# Additional consumption = H x slope_m x sum_j [ DD(T_j) - DD(T_j - delta_m) ]
#   H        primary dwellings with air conditioning
#   slope_m  kWh per equipped dwelling, per day and per degree above the
#            threshold, calibrated on the consumption measured by SPAHOUSEC III
#            in the same month of 2022
#   DD(T)    max(Tmax - threshold, 0), Tmax at AEMET station 8416
#   delta_m  warming attributable to climate change (Barnes et al. 2026)
# Cost = additional consumption of the day x day-ahead spot price (REE),
# excluding taxes. Waves 1-3 only: wave 4 (2-7 September) is provisional
# and Barnes et al. give no delta for September.
#
# Run from the repository root. Reads only the files in data/.

dir.create("output", showWarnings = FALSE)

# ---------------------------------------------------------------------------
# 1. Parameters
# ---------------------------------------------------------------------------
# Equipped dwellings = population / persons per household x equipment rate
population     <- 858178  # municipal register, 1/1/2026, provisional (Ajuntament de Valencia, 9/5/2026)
household_size <- 2.5     # province of Valencia, 2025: 2,766,375 inhabitants / 1,104,496 households
                          # (Mercado Inmobiliario de Valencia, 2nd quarter 2025)
equipment_rate <- 248337 / 317688  # 78.2%; INE, ECEPOV 2021, table 56804, city of Valencia:
                                   # primary dwellings with a cooling system / all primary dwellings
H <- population / household_size * equipment_rate

# Cooling consumption MEASURED in 2022, Mediterranean zone (IDAE 2026, SPAHOUSEC III):
# results file 34 ("Curva carga por zona climatica"), use "Refrigeracion",
# zone "Mediterraneo", sum of the hours of the month (GWh); results file 04:
# primary dwellings, zone "Mediterraneo", cooling "Si"
# (5,410,345.8 multi-family + 2,572,832.1 single-family).
cooling_2022_gwh <- c("2022-06" = 372.849, "2022-07" = 600.335, "2022-08" = 485.211, "2022-09" = 309.797)
equipped_med     <- 5410345.791991 + 2572832.115258

threshold      <- 24   # degC on Tmax (household set point; assumption)
threshold_tmed <- 21   # degC on Tmed, 18 + 3 degC (Valor et al. 2001), method A2

# Independent physical model (method C), for comparison only
floor_area_m2  <- 89.16  # INE, Census 2021, province of Valencia
share_cooled   <- 0.50   # assumption
frigories_m2   <- 100    # installer rule of thumb
eer            <- 3.4    # median of Eurovent-certified splits, 2016 (Viegand Maagoe & ARMINES 2018)
hours_day      <- 2.55   # SPAHOUSEC III, results file 27, Mediterranean primary dwellings

# Household electricity use of the city: 3.46 kWh per inhabitant and per day,
# 2023 annual mean (Ajuntament de Valencia, indicator 06153310, from Iberdrola)
household_kwh_per_inhabitant_day <- 3.46

# ---------------------------------------------------------------------------
# 2. Data
# ---------------------------------------------------------------------------
temp  <- read.csv("data/aemet_8416_daily_jun-sep_2016-2026.csv")
price <- read.csv("data/ree_daily_prices_jun-aug_2026.csv")
delta <- read.csv("data/delta_barnes_2026_valencia.csv")
waves <- read.csv("data/heatwaves_aemet_2026.csv")
temp$date  <- as.Date(temp$date)
price$date <- as.Date(price$date)
temp$ym    <- format(temp$date, "%Y-%m")

waves <- waves[waves$status == "final", ]
days <- do.call(rbind, lapply(seq_len(nrow(waves)), function(i)
  data.frame(wave = waves$wave[i], date = seq(as.Date(waves$start[i]), as.Date(waves$end[i]), by = "day"))))
days$month <- as.integer(format(days$date, "%m"))
days <- merge(days, temp[, c("date", "tmax", "tmed")], by = "date")
days <- merge(days, price, by = "date")
days <- merge(days, delta[, c("month", "delta", "delta_low", "delta_high")], by = "month")
days <- days[order(days$date), ]
stopifnot(nrow(days) == sum(waves$n_days), !anyNA(days))

# ---------------------------------------------------------------------------
# 3. Slope (kWh per equipped dwelling, per day and per degree)
# ---------------------------------------------------------------------------
dd <- function(t, s) pmax(t - s, 0)
months_2022 <- names(cooling_2022_gwh)
kwh_day <- 1e6 * cooling_2022_gwh / sapply(months_2022, function(m) sum(temp$ym == m)) / equipped_med
mean_dd_2022 <- function(var, s) sapply(months_2022, function(m) mean(dd(temp[[var]][temp$ym == m], s)))
monthly_slope <- function(var, s) setNames(kwh_day / mean_dd_2022(var, s), substr(months_2022, 6, 7))
constant <- function(x) setNames(rep(x, 4), substr(months_2022, 6, 7))

# B: line fitted on June-September 2022, slope and threshold estimated together
tm <- sapply(months_2022, function(m) mean(temp$tmed[temp$ym == m]))
fit <- lm(kwh_day ~ tm)
slope_B <- unname(coef(fit)[2]); threshold_B <- unname(-coef(fit)[1] / coef(fit)[2])
# C: physical model, full load at the mean annual maximum of Tmax 2016-2025
past  <- temp[format(temp$date, "%Y") <= "2025", ]
t_dim <- mean(tapply(past$tmax, format(past$date, "%Y"), max))
power_kw <- floor_area_m2 * share_cooled * frigories_m2 * 1.163 / eer / 1000
slope_C  <- power_kw * hours_day / (t_dim - threshold)

methods <- list(
  A1 = list(name = "A1. SPAHOUSEC III, same month of 2022, Tmax, 24 degC [main]",
            var = "tmax", s = threshold, slope = monthly_slope("tmax", threshold)),
  A2 = list(name = "A2. Same measurement, Tmed, 21 degC",
            var = "tmed", s = threshold_tmed, slope = monthly_slope("tmed", threshold_tmed)),
  B  = list(name = "B.  Line fitted on June-September 2022 (Tmed, estimated threshold)",
            var = "tmed", s = threshold_B, slope = constant(slope_B)),
  C  = list(name = "C.  Physical model (area, capacity, EER, hours)",
            var = "tmax", s = threshold, slope = constant(slope_C)))

# ---------------------------------------------------------------------------
# 4. Additional consumption and cost, day by day
# ---------------------------------------------------------------------------
by_day <- function(m, d = days$delta, prices = days$spot_eur_mwh) {
  slope <- m$slope[sprintf("%02d", days$month)]
  mwh <- H * slope * (dd(days[[m$var]], m$s) - dd(days[[m$var]] - d, m$s)) / 1000
  data.frame(wave = days$wave, mwh = mwh, eur = mwh * prices)
}
main <- methods$A1
d0 <- by_day(main); dl <- by_day(main, days$delta_low); dh <- by_day(main, days$delta_high)

# Table 10
by_wave <- do.call(rbind, lapply(c(unique(days$wave), "Total"), function(v) {
  k <- if (v == "Total") rep(TRUE, nrow(days)) else days$wave == v
  data.frame(wave = v, days = sum(k), mean_spot_eur_mwh = round(mean(days$spot_eur_mwh[k]), 2),
             mwh = round(sum(d0$mwh[k])), cost_eur = round(sum(d0$eur[k])),
             cost_low = round(sum(dl$eur[k])), cost_high = round(sum(dh$eur[k])))
}))

by_method <- do.call(rbind, lapply(methods, function(m) {
  d <- by_day(m)
  data.frame(method = m$name, threshold = round(m$s, 1), mwh = round(sum(d$mwh)), cost_eur = round(sum(d$eur)))
}))
by_method$vs_main_pct <- round(100 * (by_method$cost_eur / by_method$cost_eur[1] - 1), 1)

m25 <- main; m25$s <- 25; m25$slope <- monthly_slope("tmax", 25)
sensitivity <- data.frame(
  variant = c("Main", "Threshold 25 degC", "Regulated household tariff (PVPC) before taxes"),
  cost_eur = round(c(sum(d0$eur), sum(by_day(m25)$eur), sum(by_day(main, prices = days$pvpc_eur_mwh)$eur))))
sensitivity$vs_main_pct <- round(100 * (sensitivity$cost_eur / sensitivity$cost_eur[1] - 1), 1)

# Checks reported in the paper
min_tmax  <- min(days$tmax)
below     <- sum(days$tmax - days$delta_high < threshold)
household <- household_kwh_per_inhabitant_day * population * nrow(days) / 1e3   # MWh

# ---------------------------------------------------------------------------
# 5. Output
# ---------------------------------------------------------------------------
options(width = 160)
cat("Waves:", paste(unique(days$wave), collapse = ", "), "-", nrow(days), "days\n")
cat("Equipped dwellings H:", round(H), "\n")

cat("\nTable 4: monthly calibration of the slope (SPAHOUSEC III, station 8416)\n")
print(data.frame(month = months_2022, cooling_gwh = round(cooling_2022_gwh, 1),
                 kwh_per_dwelling_day = round(kwh_day, 2),
                 mean_degrees_above_24 = round(mean_dd_2022("tmax", threshold), 2),
                 slope_kwh_per_degC = round(main$slope, 3)), row.names = FALSE)

cat(sprintf("\nLowest Tmax on a heatwave day: %.1f degC; days below the threshold with the upper delta: %d\n",
            min_tmax, below))
cat(sprintf("Additional consumption: %.0f MWh (%.0f-%.0f with the bounds of delta)\n",
            sum(d0$mwh), sum(dl$mwh), sum(dh$mwh)))
cat(sprintf("July: %.2f kWh per equipped dwelling and per day (slope %.3f x delta %.2f)\n",
            main$slope["07"] * delta$delta[delta$month == 7], main$slope["07"], delta$delta[delta$month == 7]))

cat("\nTable 10: additional consumption and cost by wave (spot price)\n")
print(by_wave, row.names = FALSE)
cat("\nCalibrations of the slope\n"); print(by_method, row.names = FALSE)
cat("\nSensitivity\n"); print(sensitivity, row.names = FALSE)
cat(sprintf("\nShare of household electricity use of the city over %d days at its 2023 mean: %.1f%%\n",
            nrow(days), 100 * sum(d0$mwh) / household))

write.csv(by_wave, "output/electricity_by_wave.csv", row.names = FALSE)
write.csv(by_method, "output/electricity_by_method.csv", row.names = FALSE)
write.csv(sensitivity, "output/electricity_sensitivity.csv", row.names = FALSE)
