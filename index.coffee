module.exports =
  initialize: (done) ->
    @app.addRoute 'all', '/admin/banking', 'members-area-banking#banking#index'

    @hook 'navigation_items', @modifyNavigationItems.bind(this)
    done()

  modifyNavigationItems: ({addItem}) ->
    addItem 'admin',
      title: 'Banking'
      id: 'members-area-banking-banking-index'
      href: '/admin/banking'
      permissions: ['admin']
      priority: 20
