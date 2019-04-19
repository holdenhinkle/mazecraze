require './config/environment'

use Rack::Static, :urls => ['/css', '/js', '/images'], :root => 'assets'
use HomepageController
use PlayController
run ApplicationController