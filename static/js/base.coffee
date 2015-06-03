React = require 'react/addons'
k = require 'kefir'
somata = require './somata-socketio'

AppDispatcher =
    mode: 'search' # search / browse

    updateStream: k.emitter()

    openUser: (user) ->
        AppDispatcher.mode = 'browse'
        BrowseDispatcher.reset()
        BrowseDispatcher.mode = 'user'
        BrowseDispatcher.item = user
        BrowseDispatcher.load()
        AppDispatcher.updateStream.emit true

SearchDispatcher =
    loading: false
    kind: 'tracks'
    q: ''
    results: []

    updateStream: k.emitter()

    search: ->
        return if !SearchDispatcher.q.length
        SearchDispatcher.loading = true
        SearchDispatcher.updateStream.emit true
        somata.remote 'soundcloud', 'searchKind', SearchDispatcher.kind, SearchDispatcher.q, (err, results) ->
            SearchDispatcher.loading = false
            SearchDispatcher.results = results
            SearchDispatcher.updateStream.emit true

capitalize = (type) ->
    type[0].toUpperCase() + type.slice(1)

BrowseDispatcher =
    reset: ->
        BrowseDispatcher.loading = false
        BrowseDispatcher.item = null
        BrowseDispatcher.mode = 'user'
        BrowseDispatcher.kind = 'tracks'
        BrowseDispatcher.results = []

    updateStream: k.emitter()

    load: ->
        return if !BrowseDispatcher.item?
        BrowseDispatcher.loading = true
        BrowseDispatcher.updateStream.emit true
        getMethod = 'get' + capitalize(BrowseDispatcher.mode) + capitalize(BrowseDispatcher.kind)
        somata.remote 'soundcloud', getMethod, BrowseDispatcher.item.id, (err, results) ->
            BrowseDispatcher.loading = false
            BrowseDispatcher.results = results
            BrowseDispatcher.updateStream.emit true

BrowseDispatcher.reset()

SearchBar = React.createClass
    getInitialState: ->
        q: SearchDispatcher.q
        kind: SearchDispatcher.kind

    componentDidMount: ->
        @focusInput()

    focusInput: ->
        @refs.input.getDOMNode().focus()

    doSearch: ->
        SearchDispatcher.q = @state.q
        SearchDispatcher.search()

    onKeyDown: (e) ->
        if e.keyCode == 13 # enter
            @doSearch()

    changeQ: (e) ->
        q = e.target.value
        @setState {q}

    changeKind: (kind) ->
        @setState {kind}
        SearchDispatcher.kind = kind
        SearchDispatcher.search()
        @focusInput()

    render: ->
        <div className='search'>
            <i className='fa fa-search' />
            <input ref='input' type='text' value=@state.q onKeyDown=@onKeyDown onChange=@changeQ placeholder={"Search for #{@state.kind}..."} />
            <KindToggle onToggle=@changeKind />
        </div>

KindToggle = React.createClass
    getInitialState: ->
        kind: SearchDispatcher.kind

    onToggle: (kind) ->
        @setState {kind}
        @props.onToggle kind

    render: ->
        choose = (kind) => => @onToggle kind
        <div className={'kind-toggle selected-' + @state.kind}>
            <i className='select-tracks fa fa-music' onClick=choose('tracks') />
            <i className='select-users fa fa-user' onClick=choose('users') />
        </div>

SearchResults = React.createClass
    getInitialState: ->
        loading: SearchDispatcher.loading
        results: SearchDispatcher.results
        kind: SearchDispatcher.kind

    updateState: ->
        @setState @getInitialState()

    componentDidMount: ->
        SearchDispatcher.updateStream.onValue @updateState

    componentWillUnmount: ->
        SearchDispatcher.updateStream.offValue @updateState

    render: ->
        if @state.loading
            <p className='card empty'>Loading...</p>

        else if @state.results?.length
            <div className='card'>{@state.results.map @renderResult}</div>

        else
            <p className='card empty'>No results.</p>

    renderResult: (result) ->
        switch @state.kind
            when 'tracks' then <TrackBlock track=result />
            when 'users' then <UserBlock user=result />

TrackBlock = React.createClass
    playTrack: ->
        somata.remote 'soundberry', 'playChannel', {slug: @props.track.title, seed_ids: [@props.track.id]}, ->

    render: ->
        <div className='track block' onClick=@playTrack>
            <span className='indicator'><i className='fa fa-play' /></span>
            <img className='artwork' src=@props.track.artwork_url />
            <div className='details'>
                <span className='title'>{@props.track.title} </span>
                <span className='username'>{@props.track.user.username}</span>
                <div className='stats'>
                    <span className='stat'><i className='fa fa-play' /> {@props.track.playback_count}</span>
                    <span className='stat'><i className='fa fa-heart' /> {@props.track.favoritings_count}</span>
                </div>
            </div>
        </div>

UserBlock = React.createClass
    openUser: ->
        AppDispatcher.openUser @props.user

    render: ->
        <div className='user block' onClick=@openUser>
            <span className='indicator'><i className='fa fa-chevron-right' /></span>
            <img className='avatar' src=@props.user.avatar_url />
            <div className='details'>
                <span className='username'>{@props.user.username}</span>
                <div className='stats'>
                    <span className='stat'><i className='fa fa-music' /> {@props.user.track_count}</span>
                    <span className='stat'><i className='fa fa-user' /> {@props.user.followers_count}</span>
                </div>
            </div>
        </div>

Search = React.createClass
    render: ->
        <div>
            <SearchBar />
            <SearchResults />
        </div>

UserFocus = React.createClass
    render: ->
        <div className='user block focus' onClick=@openUser>
            <img className='avatar' src=@props.user.avatar_url />
            <div className='details'>
                <span className='username'>{@props.user.username}</span>
                <div className='stats'>
                    <span className='stat'><i className='fa fa-map-marker' /> {@props.user.city}</span>
                </div>
            </div>
        </div>

BrowseBar = React.createClass
    getInitialState: ->
        selected: BrowseDispatcher.kind

    updateState: ->
        @setState @getInitialState()

    componentDidMount: ->
        BrowseDispatcher.updateStream.onValue @updateState

    componentWillUnmount: ->
        BrowseDispatcher.updateStream.offValue @updateState

    selectItem: (s) ->
        @setState selected: s
        BrowseDispatcher.kind = s
        BrowseDispatcher.load()

    render: ->
        isSelected = (s) => @state.selected == s
        itemClass = (s) -> React.addons.classSet
            'bar-item': true
            'selected': isSelected s
        select = (s) => => @selectItem s

        barItem = (s, i, t) ->
            <a className=itemClass(s) onClick=select(s)>
                <i className={'fa '+i} /> {s.toUpperCase()}
            </a>

        <div className={"bar #{BrowseDispatcher.kind}-bar"}>
            {barItem 'tracks', 'fa-music'}
            {barItem 'favorites', 'fa-heart'}
            {barItem 'following', 'fa-users'}
        </div>

Browse = React.createClass
    render: ->
        focus_item = switch BrowseDispatcher.mode
            when 'track' then <TrackFocus track=BrowseDispatcher.item /> # TODO
            when 'user' then <UserFocus user=BrowseDispatcher.item />
        <div className='browse'>
            {focus_item}
            <BrowseBar />
            <BrowseResults />
        </div>

BrowseResults = React.createClass
    getInitialState: ->
        loading: BrowseDispatcher.loading
        results: BrowseDispatcher.results
        kind: BrowseDispatcher.kind

    updateState: ->
        @setState @getInitialState()

    componentDidMount: ->
        BrowseDispatcher.updateStream.onValue @updateState

    componentWillUnmount: ->
        BrowseDispatcher.updateStream.offValue @updateState

    render: ->
        if @state.loading
            <p className='card empty'>Loading...</p>

        else if @state.results?.length
            <div className='card'>{@state.results.map @renderResult}</div>

        else
            <p className='card empty'>No results.</p>

    renderResult: (result) ->
        switch @state.kind
            when 'tracks' then <TrackBlock track=result />
            when 'favorites' then <TrackBlock track=result />
            when 'following' then <UserBlock user=result />

SoundcloudWidget = React.createClass
    getInitialState: ->
        mode: AppDispatcher.mode

    updateState: ->
        @setState @getInitialState()

    componentDidMount: ->
        AppDispatcher.updateStream.onValue @updateState

    componentWillUnmount: ->
        AppDispatcher.updateStream.offValue @updateState

    openSearch: ->
        AppDispatcher.mode = 'search'
        AppDispatcher.updateStream.emit true

    render: ->

        display = switch @state.mode
            when 'search' then <Search />
            when 'browse' then <Browse />

        searchBtnClass = React.addons.classSet
            'search-btn': true
            selected: @state.mode == 'search'

        <div id='soundcloud-widget'>
            <h2><i className='fa fa-soundcloud' /> SoundCloud</h2>
            <a className=searchBtnClass onClick=@openSearch><i className='fa fa-search' /></a>
            {display}
        </div>

window.AppDispatcher = AppDispatcher
window.BrowseDispatcher = BrowseDispatcher
window.SearchDispatcher = SearchDispatcher

# Load up test data

oshi =
    id: 33814476
    track_count: 23
    followers_count: 42755
    username: 'oshi'
    avatar_url: 'https://i1.sndcdn.com/avatars-000146337345-4l8pym-large.jpg'
    city: 'London, UK'

AppDispatcher.mode = 'browse'
BrowseDispatcher.mode = 'user'
BrowseDispatcher.item = oshi

# Go

React.render <SoundcloudWidget />, document.getElementById 'app'

