class Hash
  def deep_get(*args)
    args.inject(self) do |intermediate, key|
      if intermediate.respond_to?(:[])
        intermediate[key]
      else
        return nil
      end
    end
  end
end
