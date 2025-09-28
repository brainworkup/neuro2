
#' Execution Tracker - Prevents Multiple Runs
#' 
#' Use this to track what has been executed and prevent re-runs

ExecutionTrackerR6 <- R6::R6Class(
  "ExecutionTrackerR6",
  public = list(
    executed_tasks = NULL,
    execution_log = NULL,
    
    initialize = function() {
      self$executed_tasks <- list()
      self$execution_log <- data.frame(
        task = character(),
        time = character(),
        status = character(),
        stringsAsFactors = FALSE
      )
    },
    
    can_execute = function(task_id) {
      # Check if task has already been executed
      if (task_id %in% names(self$executed_tasks)) {
        message("Task already executed: ", task_id)
        return(FALSE)
      }
      return(TRUE)
    },
    
    mark_executed = function(task_id, status = "success") {
      self$executed_tasks[[task_id]] <- Sys.time()
      self$execution_log <- rbind(
        self$execution_log,
        data.frame(
          task = task_id,
          time = as.character(Sys.time()),
          status = status,
          stringsAsFactors = FALSE
        )
      )
    },
    
    reset = function() {
      self$executed_tasks <- list()
      self$execution_log <- self$execution_log[0,]
      message("Execution tracker reset")
    },
    
    get_summary = function() {
      list(
        total_executed = length(self$executed_tasks),
        tasks = names(self$executed_tasks),
        log = self$execution_log
      )
    }
  )
)

# Global tracker instance
.EXECUTION_TRACKER <- ExecutionTrackerR6$new()

# Helper function for safe execution
safe_execute <- function(task_id, func, ...) {
  if (.EXECUTION_TRACKER$can_execute(task_id)) {
    tryCatch({
      result <- func(...)
      .EXECUTION_TRACKER$mark_executed(task_id, "success")
      return(result)
    }, error = function(e) {
      .EXECUTION_TRACKER$mark_executed(task_id, "error")
      stop(e)
    })
  } else {
    message("Skipping already executed task: ", task_id)
    return(NULL)
  }
}

