# URL Request Operation
Using OperationQueue for your URL requests (with an built-in retry mechanism).

## How to Use
Here is the detailed lifespan of an `URLRequestOperation`:
1. Init. Not much to tell here…
2. Request Launch:
   1. First, the URL is processed for running. Which means the method
      `processURLRequestForRunning` is called. This is an override point for
      subclasses if they want to prevent the request to run depending on certain
      condition, or if they want to modify the URL Request prior running it.
      
      This processing might take some time, or be expensive resource-wise, which
      is why you can specify a queue on which the processing will be done. (This
      is the `queueForProcessingURLRequestForRunning` property.)
      
      If the processing fails (returns an error), the operation will go to the
      error processing step (4) with the given error (the operation might be
      retried later depending on the error processing result).
   2. Next, the session task is created. The creation of the task and the
      behavior of the operation will differ depending on the delegate of the URL
      session given to the operation.
      - Session delegate is an instance of `URLRequestOperationSessionDelegate`:
        The task is created with `urlSessionTaskForURLRequest(_:withDelegate)`
        (which can be overridden if need be). By default, in this method, the
        session delegate is told to forward the delegate method regarding this
        specific task to the operation (the delegate of an URL session is a
        global delegate and cannot be set by task without this hack AFAIK).

        If subclasses overwrite this method and decide to work a different way
        for the delegate method, they will be responsible for receiving the data
        and treating it, then **must** call
        `urlSession(_:task:didCompleteWithError:)` when the task is done.
      - Session delegate is kind of another class of `nil`: The task is created
        with the `urlSessionTaskForURLRequest(_:,withDataCompletionHandler:,
        downloadCompletionHandler:)`.
   3. Finally the task is launched.
3. While the request is live:
   - For data tasks, when the session delegate is an instance of
     `URLRequestOperationSessionDelegate`:
     1. A URL response is received. First the method `errorForResponse(_:)` will
        check whether the response is appropriate (correct status code and mime
        type, or other pre-filters). Then the `urlResponseProcessor` will be
        called if the previous check passes. Both method can cancel the session
        task if they deem the response not worthy of continuing.
     2. Data is then received…
     3. At one point (`urlSession(_:task:didCompleteWithError:)`), the task will
        finish. `processEndOfTask(error:)` (private) is called to check what to
        do from here.
   - For data tasks, or tasks whose delegate is not of expected class, there
     will be no response processing. The next step will be when the task is
     finished: `processEndOfTask(error:)` is called.
4. Processing the end of the task (`processEndOfTask(error:)`):
   - If there is already a final error (eg. operation cancelled), the operation
     is ended here.
   - Otherwise the `computeRetryInfo(sourceError:completionHandler:)` method is
     called on the `queueForComputingRetryInfo` (computing the retry info might
     be an expensive operation). This method is reponsible for telling whether
     the operation should be retried, and after which delay. The default
     implementation will check the error. For a network lost for instance, the
     operation should be retried for idempotent HTTP requests. The delay
     respects an exponential backoff by default. Subclasses can override to
     implement their own logic and behavior.
     This is actually the most important override point for the operation.
     
     The `computeRetryInfo` method will also allow to decide whether some “early
     retrying” techniques should be setup. Or you can setup your own. There are
     two built-in retrying techniques: The `ReachabilityObserver` which will
     simply check when the network is reachable again and the `Other Success
     Observer` which will trigger a retry when another URLRequestOperation for
     the same host succeeds.
     
     If you decide to write your own “early retrying” methods, you should
     overwrite `removeObserverForEarlyRetrying()` and remove your observers in
     your implementation. Do not forget to call super!
     
     If the operation is told to be retried, when it is retried, we simply go
     back to step 2. (The URL is re-processed, etc.)

## License

[Apache License 2.0](License.txt)
