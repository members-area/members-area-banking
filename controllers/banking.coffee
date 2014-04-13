Controller = require 'members-area/app/controller'
_ = require 'members-area/node_modules/underscore'
async = require 'members-area/node_modules/async'
fs = require 'fs'
ofx = require 'ofx'
entities = new (require('html-entities').AllHtmlEntities)

class BankingController extends Controller
  @before 'requireAdmin'
  @before 'processOFX', only: ['index']

  index: (done) ->
    @req.models.TransactionAccount.find()
    .order("id", "ASC")
    .all (err, @transactionAccounts) =>
      done(err)

  view: (done) ->
    @req.models.TransactionAccount.get @req.params.id, (err, @transactionAccount) =>
      return done err if err
      @transactionAccount.getTransactions (err, @transactions) =>
        done(err)

  requireAdmin: (done) ->
    unless @req.user and @req.user.can('admin')
      err = new Error "Permission denied"
      err.status = 403
      return done err
    else
      done()

  processOFX: (done) ->
    return done() unless @req.method is 'POST' and @req.files?.ofxfile?
    path = @req.files.ofxfile.path
    next = (err, result) ->
      fs.unlink path
      if err
        done(err)
      else
        @ofxResults = result
        done()
    @dryRun = !@req.body.commit
    if !!@req.body.dryRun
      @dryRun = true # Just in case they send both

    @parseOFX path, (err, results) =>
      async.map results.accounts, @importOFXAccount.bind(this), (err, groupedNewRecords) =>
        @newRecords = []
        @newRecords.dryRun = @dryRun
        for group, i in groupedNewRecords
          account = results.accounts[i]
          for record in group
            @newRecords.push _.extend record,
              accountId: account.accountId
        next(err)
    return

  importOFXAccount: (data, done) ->
    {accountId, transactions} = data
    @req.models.TransactionAccount.find(identifier: accountId)
    .first (err, account) =>
      return done err if err
      next = (err) =>
        return done err if err
        account.getTransactions (err, existingTransactions) =>
          return done err if err
          @reconcileTransactions account, existingTransactions, transactions, done
      if !account
        account = new @req.models.TransactionAccount
          name: accountId
          identifier: accountId
        account.save next
      else
        next()

  reconcileTransactions: (account, oldTransactions, newTransactions, done) ->
    newRecords = []
    oldTransactionsByFitid = {}
    oldTransactionsByFitid[tx.fitid] = tx for tx in oldTransactions
    for tx in newTransactions
      oldTransaction = oldTransactionsByFitid[tx.fitid]
      continue if oldTransaction
      newRecordData =
        transaction_account_id: account.id
        fitid: tx.fitid
        when: tx.date
        type: tx.type
        description: tx.name
        amount: tx.amount
      newRecords.push newRecordData
    if @dryRun
      done(null, newRecords)
    else
      @req.models.Transaction.create newRecords, (err) ->
        return done err if err
        done null, newRecords

  parseOFX: (filename, callback) ->
    regex = /^(.*) M(0[0-9]+) ([A-Z]{3})$/
    fs.readFile filename, 'utf8', (err, ofxData) ->
      if err
        return callback err
      data = ofx.parse ofxData
      STMTTRNRS = data.OFX?.BANKMSGSRSV1?.STMTTRNRS
      STMTTRNRS = [STMTTRNRS] unless Array.isArray STMTTRNRS
      output =
        accounts: []
      for statement in STMTTRNRS
        account =
          accountId: statement.STMTRS.BANKACCTFROM?.ACCTID
          bankId: statement.STMTRS.BANKACCTFROM?.BANKID
          branchId: statement.STMTRS.BANKACCTFROM?.BRANCHID
          accountType: statement.STMTRS.BANKACCTFROM?.ACCTTYPE
          transactions: []
        transactions = account.transactions
        STMTTRN = statement.STMTRS.BANKTRANLIST?.STMTTRN
        STMTTRN = [STMTTRN] unless Array.isArray STMTTRN
        for tx in STMTTRN ? [] when tx
          type = String(tx.TRNTYPE)
          dateString = String(tx.DTPOSTED)
          date = new Date(parseInt(dateString[0..3], 10), parseInt(dateString[4..5], 10), parseInt(dateString[6..7], 10))
          amount = Math.round(parseFloat(tx.TRNAMT) * 100)
          fitid = String(tx.FITID)
          name = entities.decode String(tx.NAME)
          transactions.push {type, date, amount, fitid, name}
        transactions.sort (a, b) -> a.date - b.date
        output.accounts.push account
      callback null, output

module.exports = BankingController
