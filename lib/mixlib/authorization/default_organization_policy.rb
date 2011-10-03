require 'mixlib/authorization/org_auth_policy'

#== Default Authz Policy/Settings for Organizations
#
# SEE ALSO: https://wiki.corp.opscode.com/display/CORP/Authorization+Matrix
Mixlib::Authorization::OrgAuthPolicy.default do |org|


  debug("Creating Default Containers")
  org.has_containers( :clients, :groups, :cookbooks, :data, :containers,
                      :nodes, :roles, :sandboxes, :environments)

  debug("Creating Default Groups")
  org.has_groups(:users, :clients, :admins, "billing-admins")

  debug("Creating Global Admins Group")
  org.has_global_admins_group

  debug("Applying Policy for billing admins")
  org.group("billing-admins") do |billing_admins|
    billing_admins.have_rights(:read, :update) do |on|
      on.group("billing-admins")
    end

    billing_admins.clear_groups_from(:create, :delete, :grant)
  end

  debug("Applying Policy for Local Admins Group")
  org.group(:admins) do |admins|

    admins.includes_superuser

    admins.have_rights(:read, :update, :create, :grant, :delete) do |on|
      on.all_containers
      on.groups(:admins, :users, :clients)
      on.organization
    end
  end

  debug("Applying Policy for Users Group")
  org.group(:users) do |users|
    users.includes_superuser

    users.have_rights(:create, :read, :update, :delete) do |on|
      on.containers(:cookbooks, :data, :nodes, :roles, :environments)
    end

    users.have_rights(:read, :delete) do |on|
      on.containers(:clients)
    end

    users.have_rights(:read) do |on|
      on.containers(:groups, :containers)
      on.organization
    end

    users.have_rights(:create) do |on|
      on.containers(:sandboxes)
    end
  end

  debug("Setting Policy for Clients Group")
  org.group(:clients) do |clients|
    clients.have_rights(:read, :create) do |on|
      on.containers(:nodes)
    end

    clients.have_rights(:create, :read, :update, :delete) do |on|
      on.containers(:data)
    end

    clients.have_rights(:read) do |on|
      on.containers(:cookbooks, :environments, :roles)
    end
  end

  debug("Creating default objects")
  create_default_objects do
    # Create the Mixlib::Authorization document for the _default environment
    Mixlib::Authorization::Models::Environment.on(org_db).new(:name=>"_default", :requester_id => requesting_actor_id, :orgname=>org_name).save
  end
end
