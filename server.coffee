polar = require 'somata-socketio'
somata = require 'somata'

client = new somata.Client

app = polar.setup_app
    port: 2977
    metaserve: compilers:
        css: require('metaserve-css-styl')()
        js: require('metaserve-js-coffee-reactify')(ext: 'coffee')

app.get '/', (req, res) -> res.render 'base'

app.start()
