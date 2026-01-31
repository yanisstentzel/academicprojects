library(shiny)

ui <- fluidPage(
    sidebarLayout(
      sidebarPanel(
        selectInput("dist", "Distribution", choices = c("Exponentielle" = "exp", "Bernoulli" = "bern")),
        sliderInput("param", "Paramètre", min = 0, max = 1, value = 0.5, step = 0.1)
      ),
      mainPanel(plotOutput("plot"))
    )
  )
  server <- function(input, output) {
    output$plot <- renderPlot({
      p <- input$param
            switch(input$dist,
             "exp" = hist(rexp(1000, rate = p), main = "Exponentielle"),
             "bern" = barplot(table(rbinom(1000, 1, p)), main = "Bernoulli")
      )
    })
  }
shinyApp(ui,server)