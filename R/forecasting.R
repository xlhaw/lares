####################################################################
#' ARIMA Forecast
#' 
#' This function automates the ARIMA iterations and modeling for 
#' time forecasting. For the moment, units can only be days.
#' 
#' The ARIMA method is appropriate only for a time series that is 
#' stationary (i.e., its mean, variance, and autocorrelation should 
#' be approximately constant through time) and it is recommended 
#' that there are at least 50 observations in the input data.
#' 
#'  The model consists of two parts, an autoregressive (AR) part 
#'  and a moving average (MA) part. The AR part involves regressing 
#'  the variable on its own lagged (i.e., past) values. The MA part 
#'  involves modeling the error term as a linear combination of error 
#'  terms occurring contemporaneously and at various times in the past.
#' 
#' One thing to keep in mind when we think about ARIMA models is 
#' given by the great power to capture very complex patters of 
#' temporal correlation (Cochrane, 1997: 25)
#' 
#' @param time POSIX. Vector with date values
#' @param values Numeric. Vector with numerical values
#' @param n_future Integer. How many steps do you wish to forecast?
#' @param ARMA Integer. How many days should the model look back for ARMA?
#' Between 5 and 10 days recommmended. If set to 0 then it will forecast
#' until the end of max date's month; if set to -1, until the end of 
#' max date's following month
#' @param ARMA_min Integer. How many days should the model look back for ARMA?
#' Between 5 and 10 days recommmended. If set to 0 then it will forecast
#' until the end of max date's month; if set to -1, until the end of 
#' max date's following month
#' @param AR Integer. Force AR value if known
#' @param MA Integer. Force MA value if known
#' @param wd_excluded Character vector. Which weekdays are excluded in 
#' your training set. If there are, please define know which ones. Example:
#' c('Sunday','Thursday'). If set to 'auto' then it will detect automatically
#' which weekdays have no data and forcast without these days.
#' @param plot Boolean. If you wish to plot your results
#' @param plot_days Integer. How many days back you wish to plot?
#' @param project Character. Name of your forecast project
#' @export
forecast_arima <- function(time, values, n_future = 30, 
                           ARMA = 8, ARMA_min = 5,
                           AR = NA, MA = NA,
                           wd_excluded = NA,
                           plot = TRUE, plot_days = 90, project = NA){
  
  # require(forecast)
  # require(lubridate)
  # require(ggplot2)
  
  # ARIMA doesn't use zeroes!
  time <- time[!values == 0]
  values <- values[!values == 0]
  
  if (length(time) < 50) {
    message("It is recommended that there are at least 50 observations in the input data")
  }
  
  if (Sys.Date() %in% time) {
    message("It is recommended that you do NOT use today's data for training your data")
  }
  
  if (n_future == -1) {
    n_future <- ceiling_date(Sys.Date(), "month") + months(1) - Sys.Date() 
  }
  if (n_future == 0) {
    n_future <- ceiling_date(Sys.Date(), "month") - Sys.Date()
  }
  
  # Which AR and MA values minimize our AIC
  if (is.na(AR) & is.na(MA)) {
    arma <- c(ARMA_min:ARMA)
    combs <- expand.grid(arma, arma)
    aic <- data.frame(
      AR = combs[,1], 
      MA = combs[,2], 
      cals = rep(0, nrow(combs)))
    message("Iterating for best AR / MA combinations; there are ", nrow(aic), "!")
    # if (length(time) > 1000) { method <- "ML" } else { method <- "CSS" }
    for(i in 1:nrow(aic)){
      Tmodel <- Arima(values, order = c(aic$AR[i], 1, aic$MA[i]), method = "ML")
      aic$cals[i] <- Tmodel$aic
    }
    AR <- aic$AR[which.min(aic$cals)]
    MA <- aic$MA[which.min(aic$cals)]
    message(paste("Best combination:", AR, "and", MA))
    aic_ARIMA <- min(aic$cals)
  }
  
  model <- Arima(values, order = c(AR, 1, MA), method = "ML")
  train <- data.frame(time, values, 
                      pred = model$fitted, 
                      resid = model$residuals)
    
  # Forecast
  future_dates <- seq.Date(max(time) + 1, max(time) %m+% days(n_future), by = 1)
  if (!is.na(wd_excluded)) {
    if (wd_excluded == "auto") {
      weekdays <- data.frame(table(weekdays(time)))
      weekdays_real <- c(weekdays(seq.Date(Sys.Date(), Sys.Date() + 6, by = 1)))
      wd_excluded <- weekdays_real[!weekdays_real %in% weekdays$Var1]
      message("Automatically excluding ", vector2text(wd_excluded))
    }
    exclude <- vector2text(wd_excluded, quotes = FALSE)
    future_dates <- future_dates[!weekdays(future_dates) %in% wd_excluded]
    n_future <- length(future_dates)
  } 
  f <- forecast(model, h = n_future)
  test <- data.frame(time = future_dates, pred = f$mean, data.frame(f)[,-1])
  
  # Outut list with all results
  output <- list(model = model,
                 metrics = forecast::accuracy(model),
                 forecast = test,
                 train = train)
  
  # Plot results
  if (plot == TRUE) {
    
    if (nrow(train) > plot_days) {
      train <- train[(nrow(train)-plot_days):nrow(train), ] 
    }
    
    plotdata <- data.frame(
      rbind(
        data.frame(date = train$time, values = train$values, type = "Real"),
        data.frame(date = train$time, values = train$pred, type = "Model"),
        data.frame(date = test$time, values = test$pred, type = "Forecast")
      ))
    rects <- data.frame(start = min(future_dates), end = max(future_dates))
    
    output$plot <- ggplot(plotdata, aes(date)) +
      geom_smooth(aes(y = values), method = 'loess', alpha = 0.5) +
      geom_line(aes(y = values, colour = type)) +
      labs(x = "Date", y = "Counter", colour = "") + 
      theme_minimal() + 
      theme(legend.position = "top",
            axis.text.x=element_text(angle=60, hjust=1)) +
      scale_x_date(date_breaks = "1 month", date_labels =  "%b-%Y") +
      ggtitle("Real & Fitted Model vs Forecast (ARIMA)",
              subtitle = paste("AIC", signif(output$model$aic, 4), "|",
                               "MAE", signif(output$metrics[3], 3), "|",
                               "RMSE", signif(output$metrics[2], 3), "|",
                               "ARIMA:", AR, "- 1 -", MA)) +
      scale_color_manual(values=c("orange", "navy","purple")) +
      geom_rect(data = rects, inherit.aes = FALSE, 
                aes(
                  xmin = start, xmax = end, 
                  ymin = min(plotdata$values),
                  ymax = max(plotdata$values)), 
                color = "transparent", fill = "grey", alpha = 0.25)
    if (!is.na(project)) {
      output$plot <- output$plot +
        labs(caption = project)
    }
    plot(output$plot)
  }
  
  return(output)
  
}



####################################################################
#' Machine Learning Forecast
#' 
#' This function lets the user create a forecast setting a time series
#' and a numerical value.
#' 
#' @param time POSIX. Vector with dates or time values
#' @param values Numeric. Vector with numerical values
#' @param n_future Integer. How many steps do you wish to forecast?
#' @param use_last Boolean. Use last observation?
#' @param automl Boolean. Use lares::h2o_automl()
#' @param plot_forecast Boolean. If you wish to plot your results
#' @param plot_model Boolean. If you wish to plot your model's results
#' @param project Character. Name of your forecast project for plot title
#' @export
forecast_ml <- function(time, values, 
                        n_future = 15, 
                        use_last = TRUE, 
                        automl = FALSE, 
                        plot_forecast = TRUE, 
                        plot_model = FALSE,
                        project = "Simple Forecast using Machine Learning") {

  # require(timetk)
  # require(tidyquant)
  
  if (length(time) != length(values)) {
    stop("The parameters 'time' and 'values' should have the same length")
  }
  
  df <- data.frame(time = time, amount = values)
  if (use_last == FALSE) {
    df <- arrange(df, desc(time)) %>% slice(-1)
    n_future <- n_future + 1
  }
  
  # STEP 1: AUGMENT TIME SERIES SIGNATURE
  augmented <- df %>% tk_augment_timeseries_signature()
  augmented <- mutate(augmented, 
                      month.lbl = as.character(month.lbl),
                      wday.lbl = as.character(wday.lbl))
  
  # STEP 2: BUILD FUTURE (NEW) DATA
  idx <- augmented %>% tk_index()
  future_idx <- idx %>% tk_make_future_timeseries(n_future = n_future)
  new_data_tbl <- future_idx %>% tk_get_timeseries_signature() %>%
    mutate(month.lbl = as.character(month.lbl),
           wday.lbl = as.character(wday.lbl))
  
  # STEP 3: MODEL
  if (automl == FALSE) {
    fit_lm <- lm(amount ~ ., data = select(augmented, -c(time)))
    pred <- predict(fit_lm, newdata = select(new_data_tbl, -c(index)))
    predictions_tbl <- tibble(time = future_idx, amount = pred) 
  } else {
    augmented_h2o <- augmented %>% dplyr::rename(tag = amount)
    fit_auto <- h2o_automl(df = augmented_h2o, alarm = FALSE, project = project)
    pred <- h2o.predict(fit_auto$model, as.h2o(new_data_tbl))
    predictions_tbl <- tibble(time = future_idx, amount = as.vector(pred))
  }
  
  # STEP 5: COMPARE ACTUAL VS PREDICTIONS
  rects <- data.frame(start = min(future_idx), end = max(future_idx))
  message("Predicted range: ", rects$start, " to ", rects$end)
  forecast <- df %>%
    ggplot(aes(x = time, y = amount)) + 
    labs(title = project, y = "Amount", x = "",
         subtitle = "Using simple multivariate regressions on time series with Machine Learning") +
    # Training data
    geom_line(color = palette_light()[[1]]) +
    geom_point(color = palette_light()[[1]]) +
    geom_smooth(method = 'loess', formula = 'y ~ x', alpha = 0.5) +
    # Predictions
    geom_line(aes(y = amount), color = palette_light()[[2]], data = predictions_tbl) +
    geom_point(aes(y = amount), color = palette_light()[[2]], data = predictions_tbl) +
    # Actuals
    geom_line(color = palette_light()[[1]], data = df) +
    geom_point(color = palette_light()[[1]], data = df) +
    # Aesthetics
    scale_x_date(date_breaks = "1 month", date_labels = "%b") +
    theme_tq() + 
    geom_rect(data = rects, inherit.aes = FALSE, 
              aes(
                xmin = start, xmax = end, ymin = 0,
                ymax = max(df$amount) * 1.02), 
              color = "transparent", fill = "orange", alpha = 0.3)
  
  if (plot_forecast == TRUE) {
    print(forecast)
  }
  
  if (plot_model == TRUE) {
    Sys.sleep(1)
    mplot_full(
      tag = df$amount, 
      score = predictions_tbl$amount[1:length(df$amount)],
      subtitle = project)
    Sys.sleep(4)
  }
  
  df_final <- rbind(df, predictions_tbl)
  
  if (automl == TRUE) {
    model <- fit_auto
    score <- fit_auto$scores$score
  } else {
    model <- fit_lm
    score <- fit_lm$fitted.values
  }
  
  output <- list(data = df_final, 
                 model = model, 
                 errors = errors(df$amount, score))
  
  return(output)
  
}  
