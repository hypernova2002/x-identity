# Request bodies are parsed by strict request models; a wrapped duplicate key would be rejected as unknown.
ActiveSupport.on_load(:action_controller) do
  wrap_parameters format: []
end
