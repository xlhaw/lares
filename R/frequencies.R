####################################################################
#' Frequencies Calculations and Plot
#' 
#' This function lets the user group, count, calculate 
#' percentages and cumulatives. It also plots if needed. 
#' Perfect for using with dplyr pipes.
#' 
#' @param vector Vector to group, count, and mutate
#' @param plot Boolean. Do you wish to see a plot?
#' @param rm.na Boolean. Remove NAs from plot?
#' @export
freqs <- function(vector, ..., plot = FALSE, rm.na = FALSE) {
  
  require(dplyr)
  require(lazyeval)
  
  output <- vector %>%
    group_by_(.dots = lazy_dots(...)) %>%
    tally() %>% arrange(desc(n)) %>%
    mutate(p = round(100*n/sum(n),2), pcum = cumsum(p))
  
  if (plot == TRUE) {
    
    if (ncol(output) - 3 <= 2) { 
      
      require(ggplot2)
      require(scales)
      options(warn=-1)
      
      plot <- ungroup(output)
      
      if (rm.na == TRUE) {
        plot <- plot[complete.cases(plot), ]
      }
      
      # Create some dynamic aesthetics
      plot$labels <- paste0(plot$n," (",plot$p,"%)")
      plot$label_colours <- ifelse(plot$p > mean(range(plot$p)) * 1.1, "m", "f")
      lim <- 0.35
      plot$label_hjust <- ifelse(
        plot$n < min(plot$n) + diff(range(plot$n)) * lim, -0.1, 1.05)
      plot$label_colours <- ifelse(
        plot$label_colours == "m" & plot$label_hjust < lim, "f", plot$label_colours)
      variable <- colnames(plot)[1]
      colnames(plot)[1] <- "names"
      
      # When two features
      if (ncol(output) - 3 == 2) { 
        facet_name <- colnames(plot)[2]
        colnames(plot)[1] <- "facet"
        colnames(plot)[2] <- "names"
        plot$facet[is.na(plot$facet)] <- "NA"
      }
      
      # Plot base
      p <- ggplot(plot, aes(x = reorder(as.character(names), n),
                            y = n, label = labels, 
                            fill = p)) +
        geom_col(alpha=0.9, width = 0.8) +
        geom_text(aes(
          hjust = label_hjust,
          colour = label_colours), size = 2.6) + lares::gg_text_customs() +
        coord_flip() + theme_minimal() + guides(colour = FALSE) +
        labs(x = "", y = "Counter", fill = "[%]",
             title = paste("Frequencies and Percentages:", variable)) +
        scale_fill_gradient(low = "lightskyblue2", high = "navy")
      
      # When two features
      if (ncol(output) - 3 == 2) { 
        p <- p + facet_grid(as.character(facet) ~ .) + 
          labs(subtitle = paste("Inside the facet grids:", facet_name)) +
          theme_light()
      }
      print(p)
    } else {
      # When more than two features
      message("Sorry, but we are not able to plot more than two feature for now...")
    }
  }
  
  return(output)
  
}