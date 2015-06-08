Puppet::Util::Reference.newreference :metaparameter, :doc => "All Puppet metaparameters and all their details" do
  types = {}
  Puppet::Type.loadall

  Puppet::Type.eachtype { |type|
    next if type.name == :puppet
    next if type.name == :component
    types[type.name] = type
  }

  str = %{

Metaparameters are attributes that work with any resource type, including custom
types and defined types.

In general, they affect _Puppet's_ behavior rather than the desired state of the
resource. Metaparameters do things like add metadata to a resource (`alias`,
`tag`), set limits on when the resource should be synced (`require`, `schedule`,
etc.), prevent Puppet from making changes (`noop`), and change logging verbosity
(`loglevel`).

## Available Metaparameters

}
  begin
    params = []
    Puppet::Type.eachmetaparam { |param|
      params << param
    }

    params.sort { |a,b|
      a.to_s <=> b.to_s
    }.each { |param|
      str << markdown_header(param.to_s, 3)
      str << scrub(Puppet::Type.metaparamdoc(param))
      str << "\n\n"
    }
  rescue => detail
    Puppet.log_exception(detail, "incorrect metaparams: #{detail}")
    exit(1)
  end

  str
end