module ActiveJobHelpers
  def active_job_args_wrapper(args: [], params: nil)
    if DependencyHelper.active_job_wraps_args?
      wrapped_args = {}

      if params
        if DependencyHelper.rails7_present?
          wrapped_args["_aj_ruby2_keywords"] = ["params", "args"]
          wrapped_args["args"] = []
          wrapped_args["params"] = {
            "_aj_symbol_keys" => ["foo"]
          }.merge(params)
        else
          wrapped_args["_aj_symbol_keys"] = ["foo"]
          wrapped_args.merge!(params)
        end
      else
        wrapped_args["_aj_ruby2_keywords"] = ["args"]
        wrapped_args["args"] = args
      end

      [wrapped_args]
    else
      params.nil? ? args : args + [params]
    end
  end
end
