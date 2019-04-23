require './config/environments'

use Rack::Static, :urls => ['/css', '/js', '/images'], :root => 'assets'
use HomepageController
use PlayController
use AdminController
run ApplicationController
