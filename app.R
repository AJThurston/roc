library(extrafont)
library(tidyverse)
library(shiny)
library(ggplot2)
library(caret)
library(e1071)
library(formattable)

ui <- shinyUI(navbarPage("Classification Accuracy",
#####################
#Classification Accuracy UI Panel#
#####################
  tabPanel("Scatterplot",
    fluidPage(
      fluidRow(
      column(width=2,
        helpText(h5(strong("Classification Properties: "))),            
        sliderInput("r",     label = h5("Correlation"), min = -1, max = 1, value = .50, step = .01),
        sliderInput("thresh", label = h5("Threshold"), min = -3, max = 3, value = 0, step = .01),
        numericInput("acut", label = h5("Actual Cut Score"), value = 0, step = .05),
        hr(),
        sliderInput("trans",     label = h5("Transparency"), min = 0, max = 100, value = 25, step = 5, post = "%"),
        hr(),
        checkboxInput('setseed','Set seed', value = TRUE),
        numericInput("seed", label = h5("Seed value"), value = 12345),
        hr(),
        br(),
        h2(a("@AJThurston", href="https://twitter.com/AJThurston", target="_blank"), align = "center")
       ), #Closes sidebarPanel
      
      column(width = 2,
        h6(strong(textOutput("text_TP"), align = "right")),
        h6(strong(textOutput("text_FN"), align = "right")),
        h6(strong(textOutput("text_TN"), align = "right")),
        h6(strong(textOutput("text_FP"), align = "right")),
        hr(),
        h6(strong(textOutput("text_Accuracy"), align = "right")),
        h6(textOutput("text_95CILL"), align = "right"),
        h6(textOutput("text_95CIUL"), align = "right"),
        h6(textOutput("text_NIR"), align = "right"),
        h6(textOutput("text_AccuracyPValue"), align = "right"),
        hr(),
        h6(textOutput("text_Kappa"), align = "right"),
        h6(textOutput("text_McnemarPValue"), align = "right"),
        hr(),
        h6(strong(textOutput("text_Sensitivity"), align = "right")),
        h6(strong(textOutput("text_Specificity"), align = "right")),
        h6(textOutput("text_PPV"), align = "right"),
        h6(textOutput("text_NPV"), align = "right"),
        h6(textOutput("text_Prevalence"), align = "right"),
        h6(textOutput("text_DetectionRate"), align = "right"),
        h6(textOutput("text_DetectionPrev"), align = "right"),
        h6(textOutput("text_BalancedAccur"), align = "right"),
        hr(),
        h6(textOutput("text_Precision"), align = "right"),
        h6(textOutput("text_Recall"), align = "right"),
        h6(textOutput("text_F1"), align = "right")
        ),
      
      column(width = 6, align = "center",
             plotOutput("plot")
      ),
      
      column(width=2,
        helpText(h5(strong("Distribution Properties: "))),
        numericInput("n",        label = h5("Sample Size"), value = 1000),
        numericInput("predmean", label = h5("Predicted Mean"), value = 0),
        numericInput("predSD",   label = h5("Predicted SD"), value = 1),
        numericInput("actumean", label = h5("Actual Mean"), value = 0),
        numericInput("actuSD",   label = h5("Actual SD"), value = 1)
      ) 
      
      
) #Closes fluidPage
) #Closes fluidRow
),
tabPanel("Documentation",
         fluidPage(
           fluidRow(
             column(width=6,
                    
                    p(strong("Formulas:")),
                    hr(),
                    p("Overall Accuracy = (TP + TN)/(TP + FP + FN + TN)"),  
                    p("Sensitivity = TP/(TP + FN)"), 
                    p("Specificity = TN/(FP + TN)"), 
                    br(),
                    p("PPV = (sensitivity*prevalence)/((sensitivity*prevalence)+((1???specificity)*(1???prevalence)))"),
                    p("NPV = (specificity*(1???prevalence))/(((1???sensitivity)*prevalence)+((specificity)*(1???prevalence)))"), 
                    p("Prevalence = (TP + FN)/(TP + FP + FN + TN)"),
                    p("Detection Rate = TP/(TP + FP + FN + TN)"), 
                    p("Detection Prevalence = (TP + FP)/(TP + FP + FN + TN)"),
                    p("Balanced Accuracy = (sensitivity + specificity)/2"), 
                    br(),
                    p("Precision = TP/(TP + FP)"), 
                    p("Recall = TP/(TP + FN)"),
                    p("F1 = (1 + beta2) * precision * recall/((beta2 * precision) + recall)"), 
                    p("where beta = 1 for this function."),
                    hr(),
                    a("Reproduced from 'caret' package documentation", 
                      href="https://cran.r-project.org/web/packages/caret/caret.pdf",
                      target="_blank"),
                    p("Note: TP = A, FN = C, TN = D, FP = B.")
                ),
             
             column(width=6,
                    p(strong("Contact: ")),
                    hr(),
                    h2(a("Twitter: @AJThurston", href="https://twitter.com/AJThurston", target="_blank")),
                    br(),
                    h2(a("LinkedIn: AJThurston", href="https://www.linkedin.com/in/ajthurston/", target="_blank")),
                    br(),
                    h2(a("Substack:  @AJThurston", href="https://substack.com/@AJThurston", target="_blank"))
             )
           )
         )
)
)
) #Closes ShinyUI

server <- shinyServer(function(input, output) {
  output$plot = renderPlot({

  #Simulated Data and Classification

    if(input$setseed == TRUE)
    {
      set.seed(input$seed);
    }
    
   
  x1 = rnorm(n=input$n, mean=input$predmean, sd=input$predSD) 
  y0 = rnorm(n=input$n, mean=input$actumean, sd=input$actuSD)
  y1 = x1*input$r+y0*(1-input$r^2)^0.5
  y2 = as.numeric(cut(y1, breaks = c(-3,input$thresh,3)))-1
  type = case_when(x1>input$thresh & y2 == 1 ~ 'tp',
                   x1<input$thresh & y2 == 1 ~ 'fn',
                   x1<input$thresh & y2 == 0 ~ 'tn',
                   .default = 'fp')
  Predicted = as.factor(x1>input$thresh)
  Actual = as.factor(y1>input$thresh)
  data = data.frame(x1,y1,y2,type,Predicted,Actual)
  
  #Confusion Matrix
  TP = sum(type == 'tp') #A
  FN = sum(type == 'fn') #C
  TN = sum(type == 'tn') #D
  FP = sum(type == 'fp') #B
  
  cm = confusionMatrix(data$Predicted,data$Actual)
  
  Accuracy      = percent(cm$overall[1],digits = 2)
  Kappa         =   round(cm$overall[2],digits = 2)
  AccuracyLower = percent(cm$overall[3],digits = 2)
  AccuracyUpper = percent(cm$overall[4],digits = 2)
  AccuracyNull  = percent(cm$overall[5],digits = 2)
  AccuracyPValue=   round(cm$overall[6],digits = 2)
  McnemarPValue =   round(cm$overall[7],digits = 2)
  
  Sensitivity   = percent(cm$byClass[1],digits = 2)
  Specificity   = percent(cm$byClass[2],digits = 2)
  PPV           = percent(cm$byClass[3],digits = 2)
  NPV           = percent(cm$byClass[4],digits = 2)
  Precision     = percent(cm$byClass[5],digits = 2)
  Recall        = percent(cm$byClass[6],digits = 2)
  F1            =   round(cm$overall[7],digits = 2)
  Prevalence    = percent(cm$byClass[8],digits = 2)
  DetectionRate = percent(cm$byClass[9],digits = 2)
  DetectionPrev = percent(cm$byClass[10],digits = 2)
  BalancedAccur = percent(cm$byClass[11],digits = 2)
  
#Text output -----
  output$text_TP <- renderText({paste0(" True Positives: ", TP)})
  output$text_FN <- renderText({paste0("False Negatives: ", FN)})
  output$text_TN <- renderText({paste0(" True Negatives: ", TN)})
  output$text_FP <- renderText({paste0("False Positives: ", FP)})  
  
  output$text_Accuracy        <- renderText({paste0("Overall Accuracy: ", Accuracy)})
  output$text_95CILL          <- renderText({paste0("95% CI Lower Limit: ", AccuracyLower)})
  output$text_95CIUL          <- renderText({paste0("95% CI Upper Limit: ", AccuracyUpper)})
  output$text_NIR             <- renderText({paste0("No Information Rate: ", AccuracyNull)})   
  output$text_AccuracyPValue  <- renderText({paste0("P-Value [Acc > NIR]: ", AccuracyPValue)})
  
  output$text_Kappa           <- renderText({paste0("Kappa: ", Kappa)})
  output$text_McnemarPValue   <- renderText({paste0("Mcnemar's Test P-Value: ", McnemarPValue)})
  
  output$text_Sensitivity     <- renderText({paste0("Sensitivity: ", Sensitivity)})
  output$text_Specificity     <- renderText({paste0("Specificity: ", Specificity)})
  output$text_PPV             <- renderText({paste0("Pos. Pred. Value: ", PPV)})   
  output$text_NPV             <- renderText({paste0("Neg. Pred. Value: ", NPV)})
  output$text_Prevalence      <- renderText({paste0("Prevalence: ", Prevalence)})
  output$text_DetectionRate   <- renderText({paste0("Detection Rate: ", DetectionRate)})
  output$text_DetectionPrev   <- renderText({paste0("Detection Prevalence: ", DetectionPrev)})   
  output$text_BalancedAccur   <- renderText({paste0("Balanced Accuracy: ", BalancedAccur)})

  output$text_Precision       <- renderText({paste0("Precision: ", Precision)})
  output$text_Recall          <- renderText({paste0("Recall: ", Recall)})   
  output$text_F1              <- renderText({paste0("F1: ", F1)})
  
# Plot --------------------------------------------------------------------
    ggplot(data, aes(x=x1, y=y2, color = type)) +
    scale_x_continuous(name="Predicted Outcome", limits = c(-3,3), breaks = seq(-3,3,1), expand = c(0,0)) +
    scale_y_continuous(name="Actual Outcome", limits = c(-.5,1.5), breaks = seq(0,1), expand = c(0,0)) +
    geom_jitter(alpha=.7, size=3) +
    
    # annotate("rect", xmin = input$thresh, xmax = 1.5, ymin = input$acut, ymax = 3, fill="darkgreen",alpha = input$trans/100, color="darkgreen") +
    # annotate("rect", xmin = -.5, xmax = input$thresh, ymin = input$acut, ymax = 3, fill="red",alpha = input$trans/100, color="red") +
    # annotate("rect", xmin = -.5, xmax = input$thresh, ymin = -3, ymax = input$acut, fill="darkgreen",alpha = input$trans/100, color="darkgreen") +
    # annotate("rect", xmin = input$thresh, xmax = 1.5, ymin = -3, ymax = input$acut, fill="red",alpha = input$trans/100, color="red") +
    geom_vline(xintercept = input$thresh) +
    annotate("text", x =  2.5, y =  2.5, label = "TP", color="white", size=20, fontface=2) +
    annotate("text", x = -2.5, y =  2.5, label = "FN", color="white", size=20, fontface=2) +
    annotate("text", x = -2.5, y = -2.5, label = "TN", color="white", size=20, fontface=2) +
    annotate("text", x =  2.5, y = -2.5, label = "FP", color="white", size=20, fontface=2) +
    
    theme(text = element_text(size = 20),
          panel.background = element_rect(fill = "white", color = "black"),
          axis.text.y = element_text(color = 'black'),
          axis.text.x = element_text(color = 'black'),
          panel.grid.major.y = element_blank(), 
          panel.grid.major.x = element_blank(),
          legend.key = element_rect(fill = NA),
          legend.position = 'none'
    )
      }, height = 200, width = 600) #Close Render Plot
})#Close server

shinyApp(ui = ui, server = server)

