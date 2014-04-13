module.exports =
  initialize: (done) ->
    @app.addRoute 'all', '/admin/banking', 'members-area-banking#banking#index'
    @app.addRoute 'all', '/admin/banking/:id', 'members-area-banking#banking#view'

    @hook 'navigation_items', @modifyNavigationItems.bind(this)
    @hook 'models:initialize', ({models}) =>
      models.Transaction.hasOne 'transaction_account', models.TransactionAccount, reverse: 'transactions', autoFetch: true

    done()

  modifyNavigationItems: ({addItem}) ->
    addItem 'admin',
      title: 'Banking'
      id: 'members-area-banking-banking-index'
      href: '/admin/banking'
      permissions: ['admin']
      priority: 20
