####################################################################
#' Get Personal Portfolio's Data
#' 
#' This function lets me download my personal Excel with my Portfolio data
#' 
#' @param filename Characeter. Import a local Excel file
#' @param token_dir Character. Where is my personal token for Dropbox connection?
#' @export
get_stocks <- function(filename = NA, token_dir = "~/Dropbox (Personal)/Documentos/Docs/Data") {
  
  processFile <- function(file) {
    cash <- read.xlsx(file, sheet = 'Fondos', skipEmptyRows=TRUE, detectDates=TRUE)
    trans <- read.xlsx(file, sheet = 'Transacciones', skipEmptyRows=TRUE, detectDates=TRUE)
    port <- read.xlsx(file, sheet = 'Portafolio', skipEmptyRows=TRUE, detectDates=TRUE)
    port <- port[port$Stocks != 0,]
    mylist <- list("portfolio" = port, "transactions" = trans, "cash" = cash)
    return(mylist)
  }
  
  if (!is.na(filename)) {
    if (file.exists(filename)) {
      results <- processFile(filename)
    } else {
      stop("Error: that file doesn't exist or it's not in your working directory!")
    }
  } else {
    token_dir <- token_dir
    load(paste0(token_dir, "/token_pers.rds"))
    x <- drop_search("Portfolio LC.xlsx", dtoken = token)
    file <- "temp.xlsx"
    invisible(
      drop_download(x$matches[[1]]$metadata$path_lower,
                    local_path = file,
                    overwrite = TRUE,
                    dtoken = token))
    results <- processFile(file)
    file.remove(file)
  }
  message("File imported succesfully!")
  return(results)   
}


####################################################################
#' Download Stocks Historical Data
#' 
#' This function lets the user download stocks historical data
#' 
#' @param symbols Character Vector. List of symbols to download historical data. 
#' Example: c('VTI','TSLA')
#' @param from Date. Since when do you wish to download historical data
#' @param today Boolean. Do you wish to additionaly download today's quote?
#' @param tax Numeric. How much does of your dividends does the taxes take? 
#' Range from 0 to 99
#' @param verbose Boolean. Print results and progress while downloading?
#' @export
get_stocks_hist <- function(symbols = NA, 
                            from = NA, 
                            today = TRUE, 
                            tax = 30, 
                            verbose = TRUE) {
  
  options(warn=-1)
  options("getSymbols.warning4.0"=FALSE)
  options("getSymbols.yahoo.warning"=FALSE)
  data <- divs <- c()
  
  if (!is.na(symbols)) {
    
    if (is.na(from)) {
      from <- rep(Sys.Date() - 365, each = length(symbols))
    }
    
    if (length(from) == length(symbols)) {
      
      for(i in 1:length(symbols)) {
        
        symbol <- as.character(symbols[i])
        start_date <- as.character(from[i])
        
        values <- quantmod::getSymbols(symbol, env=NULL, from=start_date, src="yahoo") %>% data.frame()
        values <- cbind(row.names(values), as.character(symbol), values)
        colnames(values) <- c("Date","Symbol","Open","High","Low","Close","Volume","Adjusted")
        values <- mutate(values, Adjusted = rowMeans(dplyr::select(values, High, Close), na.rm = TRUE))
        row.names(values) <- NULL
        
        # Add right now's data
        if (today == TRUE) {
          quote <- function(ticks) {
            qRoot <- "https://query1.finance.yahoo.com/v7/finance/quote?fields=symbol,longName,regularMarketPrice,regularMarketChange,regularMarketTime&formatted=false&symbols="
            z <- fromJSON(paste(qRoot, paste(ticks, collapse=","), sep=""))
            z <- z$quoteResponse$result[,c("symbol", "regularMarketTime", "regularMarketPrice", "regularMarketChange", "longName")]
            row.names(z) <- z$symbol
            z$symbol <- NULL
            names(z) <- c("Time", "Price", "Change", "Name")
            z$Time <- as.POSIXct(z$Time, origin = '1970-01-01 00:00:00')
            return(z)
          }
          now <- quote(symbol)
          now <- data.frame(Date = as.character(as.Date(now$Time)), Symbol = symbol,
                            Open = now$Price, High = now$Price, Low = now$Price, Close = now$Price,
                            Volume = 0, Adjusted = now$Price)
          values <- rbind(values, now)
        }
        
        data <- rbind(data, values)
        
        # Dividends if case
        d <- quantmod::getDividends(as.character(symbol), from = start_date)
        if (nrow(d) > 0) {
          div <-  data.frame(Symbol = rep(symbol, nrow(d)),
                             Date = ymd(row.names(data.frame(d))),
                             Div = as.vector(d),
                             DivReal = as.vector(d)*(100-tax)/100)
          divs <- rbind(divs, div)
        }
        if (verbose == TRUE) {
          message(paste0(symbol, " since ", start_date," (", i, "/", length(symbols),")"))
        }
      }
    } else { message("The parameters 'symbols' and 'from' should be the same length.") }
  } else { message("You need to define which stocks to bring. Use the 'stocks=' parameter.") }
  results <- list("values" = data, "dividends" = divs)
  return(results)
}


####################################################################
#' Fix Historical Data on Stocks
#' 
#' This function lets the user fix downloaded stock data into a usefull 
#' format output
#' 
#' @param dailys Dataframe. Daily values. Structure: "Date", "Symbol", 
#' "Open", "High", "Low", "Close", "Volume", "Adjusted"
#' @param dividends Dataframe. Dividends. Structure: "Symbol", "Date", 
#' "Div", "DivReal"
#' @param transactions Dataframe. Transactions. Structure: "ID", "Inv", 
#' "CODE", "Symbol", "Date", "Quant", "Value", "Amount", "Description"
#' @param expenses Numeric. How much does that bank or broker charges per
#' transaction? Absolute value.
#' @export
stocks_hist_fix <- function (dailys, dividends, transactions, expenses = 7) {
  
  dailys_structure <- c("Date", "Symbol", "Open", "High", "Low", "Close", "Volume", "Adjusted")
  dividends_structure <- c("Symbol", "Date", "Div", "DivReal")
  trans_structure <- c("ID", "Inv", "CODE", "Symbol", "Date", "Quant", "Value", "Amount", "Description")
  
  if (colnames(dailys) != dailys_structure) {
    stop(paste("The structure of the 'dailys' table should be:",
               paste(shQuote(dailys_structure), collapse=", ")))
  }
  
  if (colnames(dividends) != dividends_structure) {
    stop(paste("The structure of the 'dividends' table should be:",
               paste(shQuote(dividends_structure), collapse=", ")))
  }
  
  if (colnames(transactions) != trans_structure) {
    stop(paste("The structure of the 'transactions' table should be:",
               paste(shQuote(trans_structure), collapse=", ")))
  }
  
  df <- dailys %>%
    mutate(Date = as.Date(as.character(Date)), Symbol = as.character(Symbol)) %>%
    arrange(Date, Symbol) %>%
    # Add transactions daily data
    left_join(transactions %>%
                mutate(Date = as.Date(as.character(Date)), Symbol = as.character(Symbol)) %>%
                dplyr::select(Symbol, Date, Quant, Value, Amount),
              by = c('Symbol','Date')) %>%
    mutate(Expenses = ifelse(is.na(Quant), 0, expenses)) %>%
    dplyr::group_by(Symbol) %>%
    mutate(Quant = ifelse(is.na(Quant), 0, Quant),
           Stocks = cumsum(Quant)) %>%
    # Add dividends daily data
    left_join(dividends %>%
                mutate(Date = as.Date(as.character(Date)), Symbol = as.character(Symbol)),
              by = c('Symbol','Date')) %>%
    mutate(DailyDiv = ifelse(is.na(DivReal), 0, Stocks * DivReal)) %>%
    # Some other cumulative calculations
    arrange(Date) %>% group_by(Stocks) %>%
    mutate(DailyValue = Close * Stocks) %>%
    arrange(desc(Date), desc(DailyValue)) %>%
    arrange(Date) %>% group_by(Symbol) %>%
    mutate(StartUSD = Value[Date == min(Date)],
           RelChangeP = 100 - (100 * lag(Close) / Close),
           RelChangeUSD = Stocks * (Close - lag(Close)) - Expenses,
           RelChangePHist = ifelse(Date == min(Date), 0, 
                                   100 - (100 * StartUSD / Close)),
           RelChangeUSDHist = Stocks * (Close - StartUSD) - sum(Expenses)) %>%
    arrange(desc(Date)) %>%
    mutate_if(is.numeric, funs(round(., 2))) %>% ungroup() %>%
    mutate_at(vars(-contains("Date")), funs(replace(., is.na(.), 0)))
  
  return(df)
  
}


####################################################################
#' Stocks Overall Performance
#' 
#' This function lets the user calculate stocks performance
#' 
#' @param dailys Dataframe. Daily values. Structure: "Date", "Symbol", 
#' "Open", "High", "Low", "Close", "Volume", "Adjusted", "Quant", 
#' "Value", "Amount", "Expenses", "Stocks", "Div", "DivReal", "DailyDiv", 
#' "DailyValue", "RelChangeP", 
#' "RelChangeUSD"
#' @param cash_in Dataframe. Deposits and withdrawals. Structure: "ID", "Date", "Cash"
#' @param cash_fix Numeric. If you wish to algebraically sum a value 
#' to your cash balance
#' @export
stocks_performance <- function(dailys, cash_in, cash_fix = 0)  {
  
  dailys_structure <- c("Date", "Symbol", "Open", "High", "Low", "Close", "Volume", "Adjusted",
                        "Quant", "Value", "Amount", "Expenses", "Stocks", "Div", "DivReal",
                        "DailyDiv", "DailyValue", "RelChangeP", "RelChangeUSD", 
                        "RelChangePHist", "RelChangeUSDHist")
  
  cash_structure <- c("ID", "Date", "Cash")
  
  if (colnames(dailys) != dailys_structure) {
    stop(paste("The structure of the 'dailys' table should be:",
               paste(shQuote(dailys_structure), collapse=", ")))
  }
  
  if (colnames(cash_in) != cash_structure) {
    stop(paste("The structure of the 'cash_in' table should be:",
               paste(shQuote(cash_structure), collapse=", ")))
  }
  
  result <- dailys %>% group_by(Date) %>%
    dplyr::summarise(Stocks = n(),
                     DailyStocks = sum(DailyValue),
                     DailyTrans = sum(Amount),
                     DailyExpen = sum(Expenses),
                     DailyDiv = sum(DailyDiv),
                     RelUSD = sum(RelChangeUSD)) %>%
    mutate(RelPer = round(100 * RelUSD / DailyStocks, 2),
           CumDiv = cumsum(DailyDiv),
           CumExpen = cumsum(DailyExpen)) %>%
    left_join(cash_in %>% dplyr::select(Date, Cash), by = c('Date')) %>%
    mutate(DailyCash = ifelse(is.na(Cash), 0, Cash),
           CumCash = cumsum(DailyCash) - cumsum(DailyTrans) + cumsum(DailyDiv) + cash_fix,
           CumPortfolio = CumCash + DailyStocks,
           TotalUSD = DailyStocks - cumsum(DailyTrans),
           TotalPer = round(100 * DailyStocks / (cumsum(DailyTrans)), 2) - 100) %>%
    dplyr::select(Date,CumPortfolio,TotalUSD,TotalPer,RelUSD,RelPer,DailyStocks,
                  DailyTrans,DailyDiv,CumDiv,DailyCash,CumCash) %>% arrange(desc(Date)) %>%
    mutate_if(is.numeric, funs(round(., 2)))
  
  return(result)
  
}


####################################################################
#' Portfolio Overall Performance
#' 
#' This function lets the user calculate portfolio performance
#' 
#' @param portfolio Dataframe. Structure: "Symbol", "Stocks", "StockIniValue", "InvPerc", "Type", "Trans", "StartDate"
#' @param daily Dataframe. Daily data
#' @export
portfolio_performance <- function(portfolio, daily) {
  
  portf_structure <- c("Symbol", "Stocks", "StockIniValue", "InvPerc", "Type", "Trans", "StartDate")
  
  if (colnames(portfolio) != portf_structure) {
    stop(paste("The structure of the 'portfolio' table should be:",
               paste(shQuote(portf_structure), collapse=", ")))
  }
  
  divIn <- daily %>% group_by(Symbol) %>%
    dplyr::summarise(DivIncome = sum(DailyDiv),
                     DivPerc = round(100 * DivIncome / sum(Amount), 2)) %>%
    arrange(desc(DivPerc))
  
  result <- left_join(portfolio %>% mutate(Symbol = as.character(Symbol)), daily[1:nrow(portfolio),] %>%
                        dplyr::select(Symbol,DailyValue), by = c('Symbol')) %>%
    mutate(DifUSD = DailyValue - Invested, DifPer = round(100 * DifUSD / Invested,2),
           StockValue = DailyValue / Stocks,
           InvPerc = 100 * InvPerc,
           RealPerc = round(100 * DailyValue/sum(DailyValue), 2)) %>%
    left_join(divIn, by = c('Symbol')) %>%
    mutate_if(is.numeric, funs(round(., 2))) %>%
    dplyr::select(Symbol:StockIniValue, StockValue, InvPerc, RealPerc, everything())
  
  return(result)
  
}


################# PLOTTING FUNCTIONS #################

####################################################################
#' Portfolio Daily Plot
#' 
#' This function lets the user plot his portfolio daily change
#' 
#' @param stocks_perf Dataframe. Output of the stocks_performance function
#' @export
portfolio_daily_plot <- function(stocks_perf) {
  
  plot <- stocks_perf %>%
    dplyr::mutate(color = ifelse(RelPer > 0, "Pos", "Neg")) %>%
    ggplot() +
    geom_area(aes(x=Date, y=TotalPer/(0.5*max(stocks_perf$TotalPer))), alpha = 0.2) +
    geom_bar(aes(x=Date, y=RelPer, fill=color), stat='identity', width=1) +
    geom_line(aes(x=Date, y=TotalPer/(0.5*max(stocks_perf$TotalPer))), alpha = 0.5) +
    geom_hline(yintercept = 0, alpha = 0.5, color="black") +
    guides(fill=FALSE) + theme_minimal() +
    scale_x_date(date_minor_breaks = "1 month", date_labels = "%b%y") +
    scale_y_continuous(breaks=seq(-100, 100, 0.5),
                       sec.axis = sec_axis(~.*(0.5 * max(stocks_perf$TotalPer)), 
                                           name = "% Portfolio Var", 
                                           breaks = seq(-100, 100, 2))) +
    labs(y = '% Daily Var', x = '',
         title = 'Daily Portfolio\'s Growth (%) since Start',
         subtitle = paste(stocks_perf$Date[1]," (Includes Expenses): ",
                          formatNum(stocks_perf$TotalPer[1],2),"% ($",
                          formatNum(stocks_perf$DailyStocks[1] - 
                                      sum(stocks_perf$DailyTrans),0),") | $",
                          formatNum(stocks_perf$CumPortfolio[1]), sep="")) +
    ggsave("portf_daily_change.png", width = 8, height = 5, dpi = 300)
  
  return(plot)
  
}


####################################################################
#' Stocks Total Performance Plot
#' 
#' This function lets the user plot his stocks total performance
#' 
#' @param stocks_perf Dataframe. Output of the stocks_performance function
#' @param portfolio_perf Dataframe. Output of the portfolio_performance function
#' @param daily Dataframe. Daily data
#' @param trans Dataframe. Transactions data
#' @param cash Dataframe. Cash data
#' @export
stocks_total_plot <- function(stocks_perf, portfolio_perf, daily, trans, cash) {
  
  tops <- max(rbind(portfolio_perf$Invested, portfolio_perf$DailyValue))
  summary <- rbind(
    paste0("Portfolio: $", formatNum(stocks_perf$CumPortfolio[1])," | ", max(daily$Date)),
    paste0("Stocks: $", formatNum(sum(stocks_perf$DailyStocks[1]),1)," & Cash: $", 
           formatNum(stocks_perf$CumCash[1],1)),
    paste0("ROI: ", formatNum(stocks_perf$TotalPer[1], 2),"% ($",
           formatNum(stocks_perf$TotalUSD[1],0),")"),
    paste0("Dividends: $", formatNum(sum(daily$DailyDiv),0)," & Expenses: $", 
           formatNum(sum(daily$Expenses),0)))
  
  plot <- portfolio_perf %>%
    mutate(shapeflag = ifelse(DifUSD < 0, 25, 24),
           box = -tops/5.5) %>%
    ggplot() + theme_minimal() +
    geom_hline(yintercept = 0, colour = "black") +
    geom_col(aes(x = reorder(Symbol, Invested), y = Invested, fill = Symbol, group = 1)) +
    geom_col(aes(x = Symbol, y = Invested + DifUSD, fill=Symbol), alpha=0.5) +
    geom_col(aes(x = Symbol, y = box), fill="grey", alpha=0.5) +
    geom_point(aes(x = Symbol, y = Invested + DifUSD, shape = shapeflag)) +
    scale_shape_identity() +
    geom_text(aes(label = paste0("$",formatNum(DifUSD,1)), y = Invested + DifUSD, x = Symbol), 
              size = 2.9, hjust = -.2, vjust = -0.2) +
    geom_text(aes(label = paste0(DifPer, "%"), y = Invested + DifUSD, x = Symbol), 
              size = 2.9, hjust = -.2, vjust = 1.2) +
    geom_text(aes(label = paste0("$", formatNum(DailyValue, 1)), y = box, x = Symbol), 
              size = 3, hjust = -.1, vjust = -0.2) +
    geom_text(aes(label = paste0(Stocks, " @$", formatNum(DailyValue/Stocks, 2)), y = box, x = Symbol), 
              size = 2, hjust = -.1, vjust = 1.5) +
    geom_text(aes(label = paste0("$", formatNum(Invested,1)), y = 0, x = Symbol), 
              size = 2, hjust = 0, vjust = -0.2) +
    geom_text(aes(label = paste0("@$", formatNum(Invested/Stocks, 2)), 
                  y = 0, x = Symbol), size = 2, hjust = 0, vjust = 1.5) +
    annotate("label", x = length(unique(portfolio_perf$Stocks))*0.25, y = tops*0.6, 
             label = vector2text(summary,"\n",quotes = F), size = 3.5, hjust = 0, alpha=0.55) +
    scale_y_continuous(limits = c(NA, tops*1.1)) + 
    labs(y='', x='', title="Stocks Distribution and Growth") +
    guides(fill=FALSE) + coord_flip() +
    ggsave("portf_stocks_change.png", width = 8, height = 8, dpi = 300)
  
  return(plot)
  
}


####################################################################
#' Stocks Daily Plot
#' 
#' This function lets the user plot stocks daily change
#' 
#' @param portfolio Dataframe. Output of the portfolio_perf function
#' @param daily Dataframe. Daily data
#' @param group Boolean. Group stocks by stocks type?
#' @export
stocks_daily_plot <- function (portfolio, daily, group = TRUE) {
  
  plot <- d <- daily %>%
    left_join(portfolio %>% dplyr::select(Symbol,Type), by='Symbol') %>%
    arrange(Date) %>% group_by(Symbol) %>%
    mutate(Hist = RelChangePHist,
           BuySell = ifelse(Amount > 0, "Bought", ifelse(Amount < 0, "Sold", NA)))
  labels <- d %>% filter(Date == max(Date))
  amounts <- d %>% filter(Amount != 0) %>%
    mutate(label = paste0(round(Amount/1000,1),"K"))
  days <- as.integer(difftime(range(d$Date)[2], range(d$Date)[1], units = "days"))
  plot <- ggplot(d) + theme_bw() + ylab('% Change since Start') +
    geom_hline(yintercept = 0, alpha=0.8, color="black") +
    geom_line(aes(x=Date, y=Hist, color=Symbol), alpha=0.9, size=0.5) +
    geom_point(aes(x=Date, y=Hist, size=abs(Amount)), alpha=0.6, colour="black") +
    scale_y_continuous(position = "right") +
    scale_size(range = c(0, 3.2)) + guides(size=F, colour=F) + 
    xlim(min(d$Date), max(d$Date) + round(days*0.08)) +
    labs(title = 'Daily Portfolio\'s Stocks Change (%) since Start', x = '',
         subtitle = 'Note that the real weighted change is not shown', colour = '') +
    geom_label_repel(data=amounts, aes(x=Date, y=Hist, label=label), size=2) +
    geom_label(data=labels, aes(x=Date, y=Hist, label=Symbol), size=2.5, hjust=-0.2, alpha=0.6)
  if (group == TRUE) {
    plot <- plot + facet_grid(Type ~ ., scales = "free", switch = "both") 
  }
  plot + ggsave("portf_stocks_histchange.png", width = 8, height = 5, dpi = 300)
  
  return(plot)
  
}


####################################################################
#' Portfolio's Distribution
#' 
#' This function lets the user plot his portfolio's distribution
#' 
#' @param portfolio_perf Dataframe. Output of the portfolio_performance function
#' @param daily Dataframe. Daily data
#' @export
portfolio_distr_plot <- function (portfolio_perf, daily) {
  
  plot_stocks <- ggplot(portfolio_perf) + theme_minimal() +
    geom_bar(aes(x = "", y = DailyValue, fill = Symbol), width = 1, stat = "identity") +
    coord_polar("y", start = 0) + scale_y_continuous(labels=scales::comma) +
    labs(x = '', y = "Portfolio's Stocks Dimentions")
  plot_areas <- ggplot(portfolio_perf) + theme_minimal() +
    geom_bar(aes(x = "", y = DailyValue/sum(DailyValue), fill = Type), width = 1, stat = "identity") +
    coord_polar("y", start = 0) + scale_y_continuous(labels = scales::percent) +
    labs(x = '', y = "Portfolio's Stocks Type Distribution")
  t1 <- tableGrob(
    portfolio_perf %>% 
      mutate(Perc = formatNum(100*DailyValue/sum(portfolio_perf$DailyValue),2),
             DailyValue = formatNum(DailyValue, 2),
             DifPer = paste0(formatNum(DifPer, 2))) %>%
      dplyr::select(Symbol, Type, DailyValue, Perc, DifPer), rows=NULL,
    cols = c("Stock","Stock Type","Today's Value","% Portaf","Growth %"))
  t2 <- tableGrob(
    portfolio_perf %>% 
      group_by(Type) %>%
      dplyr::summarise(Perc = formatNum(100*sum(DailyValue)/sum(portfolio_perf$DailyValue),2),
                       DifPer = formatNum(100*sum(DailyValue)/sum(Invested)-100,2),
                       DailyValue = formatNum(sum(DailyValue))) %>%
      dplyr::select(Type, DailyValue, Perc, DifPer) %>% 
      arrange(desc(Perc)), rows=NULL,
    cols = c("Stock Type","Today's Value","% Portaf","Growth %"))
  png("portf_distribution.png", width=700, height=500)
  grid.arrange(plot_stocks, plot_areas, t1, t2, nrow=2, heights=c(3,3))
  dev.off()
  return(grid.arrange(plot_stocks, plot_areas, t1, t2, nrow=2, heights=c(3,3)))
}


####################################################################
#' Portfolio's Calculations and Plots
#' 
#' This function lets the user create his portfolio's calculations and
#' plots for further study.
#' 
#' @param data List. Containing the following dataframes: portfolio,
#' transactions, cash. They have to follow the original xlsx format
#' @param cash_fix Numeric. If you wish to algebraically sum a value 
#' to your cash balance
#' @param tax Numeric. How much does of your dividends does the taxes take? 
#' Range from 0 to 99
#' @param expenses Numeric. How much does that bank or broker charges per
#' transaction? Absolute value.
#' @export
stocks_objects <- function(data, cash_fix = 0, tax = 30, expenses = 7) {
  
  options(warn=-1)
  
  tabs <- c('portfolio','transactions','cash')
  if (sum(names(data) %in% tabs) != 3) {
    not <- names(data)[!names(data) %in% tabs]
    stop(paste("The following objects are obligatory too:", vector2text(not)))
  }
  
  current_wd <- getwd()
  tempdir <- tempdir()
  setwd(tempdir)
  
  # Data wrangling and calculations
  message("Downloading historical and live data for each Stock...")
  hist <- get_stocks_hist(symbols = data$portfolio$Symbol, 
                          from = data$portfolio$StartDate, 
                          tax = tax)
  daily <- stocks_hist_fix(dailys = hist$values, 
                           dividends = hist$dividends, 
                           transactions = data$transactions, 
                           expenses = expenses)
  stocks_perf <- stocks_performance(daily, 
                                    cash_in = data$cash, 
                                    cash_fix = cash_fix)
  portfolio_perf <- portfolio_performance(portfolio = data$portfolio, 
                                          daily = daily)
  message("Calculations ready...")
  
  # Visualizations
  p1 <- portfolio_daily_plot(stocks_perf)
  p2 <- stocks_total_plot(stocks_perf, portfolio_perf, daily, 
                          trans = data$transactions, 
                          cash = data$cash)
  p3 <- stocks_daily_plot(portfolio = data$portfolio, daily)
  p4 <- portfolio_distr_plot(portfolio_perf, daily)
  graphics.off()
  message("Graphics ready...")
  
  # Consolidation
  results <- list(p_portf_daily_change = p1,
                  p_portf_stocks_change = p2,
                  p_portf_stocks_histchange = p3,
                  p_portf_distribution = p4,
                  df_portfolio_perf = portfolio_perf,
                  df_stocks_perf = stocks_perf,
                  df_daily = daily,
                  df_hist = hist)
  unlink(tempdir, recursive = FALSE)
  setwd(current_wd)
  message("All results are ready to export")
  
  return(results)
  
}

####################################################################
#' Portfolio's Full Report in HTML
#' 
#' This function lets the user create his portfolio's full report in HTML using
#' the library's results
#' 
#' @param results List. Containing the following objects: portf_daily_change, 
#' portf_stocks_change, portf_stocks_histchange, portf_distribution & portfolio_perf.
#' You can use simply use the stocks_objects(data) if you didn't mess with the order!
#' @export
stocks_html <- function(results) {
  
  options(warn=-1)
  dir <- getwd()
  
  # Can be more accurate with names but works for me!
  params <- list(portf_daily_change = results[[1]],
                 portf_stocks_change = results[[2]],
                 portf_stocks_histchange = results[[3]],
                 portf_distribution = results[[4]],
                 portfolio_perf = results[[5]])
  
  invisible(file.copy(
    from = system.file("docs", "stocksReport.Rmd", package = "lares"),
    to = dir, 
    overwrite = TRUE, 
    recursive = FALSE, 
    copy.mode = TRUE))
  
  rmarkdown::render("stocksReport.Rmd", 
                    output_file = "stocksReport.html",
                    params = params,
                    envir = new.env(parent = globalenv()),
                    quiet = TRUE)  
  
  invisible(file.remove(paste0(dir, "/stocksReport.Rmd")))
  message("HTML report created successfully")
  
}


####################################################################
#' Portfolio's Full Report and Email
#' 
#' This function lets the user create his portfolio's full report with plots and email sent
#' 
#' @param wd Character. Where do you wish to save the results (plots and report)?
#' @param cash_fix Numeric. If you wish to algebraically sum a value to your cash balance
#' @param mail Boolean Do you wish to send the email?
#' @param creds Character. Credential's user (see get_credentials) for sending mail
#' @export
stocks_report <- function(wd = "personal", cash_fix = 0, mail = TRUE, creds = NA) {
  
  options(warn=-1)
  
  # Setting up working directory
  current_wd <- getwd()
  if (dir.exists(wd)) {
    temp <- wd
  } else {
    temp <- tempdir() 
  }
  setwd(temp)
  
  # Set token for Sendgrid credentials:
  token_dir <- case_when(
    wd == "personal" ~ "~/Dropbox (Personal)/Documentos/Docs/Data",
    wd %in% c("matrix","server") ~ "~/creds",
    TRUE ~ as.character(creds))
  
  # Data extraction and processing
  data <- get_stocks(token_dir = token_dir)
  results <- stocks_objects(data)
  
  # HTML report
  stocks_html(results)
  
  if (mail == TRUE) {
    mailSend(body = " ", 
             subject = paste("Portfolio:", max(results$df_daily$Date)),
             attachment = paste0(getwd(), "/stocksReport.html"),
             to = "laresbernardo@gmail.com", 
             from = 'AutoReport <laresbernardo@gmail.com>', 
             creds = token_dir,
             quite = FALSE)
  }
  
  setwd(current_wd)
  
  # Clean everything up and delete files created
  unlink(temp, recursive = FALSE)
  graphics.off()
  rm(list = ls())
}

######################### SHORT #####################################
# df <- get_stocks() # Get data from my Dropbox
# dfp <- stocks_objects(df) # Make calculations and plots
# stocks_html(dfp) # Create HTML report
# stocks_report() # Create and send report to my mail

######################### LONG #####################################
# df <- get_stocks() # Get data from my Dropbox
# hist <- get_stocks_hist(symbols = df$portfolio$Symbol, from = df$portfolio$StartDate)
# daily <- stocks_hist_fix(dailys = hist$values, dividends = hist$dividends, transactions = df$transactions)
