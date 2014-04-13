Controller = require 'members-area/app/controller'

class BankingController extends Controller
  index: (done) ->
    unless @req.user and @req.user.can('admin')
      err = new Error "Permission denied"
      err.status = 403
      return done err
    done()

module.exports = BankingController
