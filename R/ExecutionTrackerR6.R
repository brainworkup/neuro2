#' Execution Tracker - Prevents Multiple Runs
#'
#' Use this to track what has been executed and prevent re-runs.
#' This R6 class maintains execution history and prevents duplicate task execution.
#'
#' @field executed_tasks List of executed tasks with their timestamps
#' @field execution_log Data frame containing execution history with task names, times, and status
ExecutionTrackerR6 <- R6::R6Class(
  "ExecutionTrackerR6",
  public = list(
    executed_tasks = NULL,
    execution_log = NULL,

    #' @description Initialize the execution tracker
    #' @param ... Additional arguments (currently unused)
    initialize = function(...) {
      self$executed_tasks <- list()
      self$execution_log <- data.frame(
        task = character(),
        time = character(),
        status = character(),
        stringsAsFactors = FALSE
      )
    },

    #' @description Check if a task can be executed
    #' @param task_id Character string identifying the task
    #' @return Logical indicating whether the task can be executed (TRUE) or has already been executed (FALSE)
    can_execute = function(task_id) {
      # Check if task has already been executed
      if (task_id %in% names(self$executed_tasks)) {
        message("Task already executed: ", task_id)
        return(FALSE)
      }
      return(TRUE)
    },

    #' @description Mark a task as executed
    #' @param task_id Character string identifying the task
    #' @param status Character string indicating execution status (default: "success")
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

    #' @description Reset the execution tracker
    #' @return Invisible NULL
    reset = function() {
      self$executed_tasks <- list()
      self$execution_log <- self$execution_log[0, ]
      message("Execution tracker reset")
    },

    #' @description Get execution summary
    #' @return List containing total executed tasks, task names, and execution log
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
    tryCatch(
      {
        result <- func(...)
        .EXECUTION_TRACKER$mark_executed(task_id, "success")
        return(result)
      },
      error = function(e) {
        .EXECUTION_TRACKER$mark_executed(task_id, "error")
        stop(e)
      }
    )
  } else {
    message("Skipping already executed task: ", task_id)
    return(NULL)
  }
}
