async = require 'async'

module.exports =
  up: (done) ->
    columns =
      id:
        type: 'number'
        serial: true
        required: true

      transaction_account_id:
        type: 'number'
        required: true

      when:
        type: 'date'
        required: true

      type:
        type: 'text'
        required: true

      description:
        type: 'text'
        required: true

      amount:
        type: 'number'
        required: true

      meta:
        type: 'object'
        required: true

      createdAt:
        type: 'date'
        required: true
        time: true

      updatedAt:
        type: 'date'
        required: true
        time: true

    transactionAccountIndex =
      table: 'transaction'
      columns: ['transaction_account_id', 'when']
      unique: false

    async.series
      createTable: (next) => @createTable 'transaction', columns, next
      addTransactionAccountIndex: (next) => @addIndex 'transaction_account_ref_idx', transactionAccountIndex, next
    , (err) ->
      console.dir err if err
      done err

  down: (done) ->
    @dropTable 'transaction', (err) ->
      console.dir err if err
      done err
