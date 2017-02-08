_ = require('lodash')
React = require('react')
d = _.merge React.DOM, require('./common'), require('./canvas'), require('./containers')
{createFactory} = d
stores = require('./stores')
moment = require('moment')
$l = require('./locale')

exports.Inbox = createFactory
  getDefaultProps: -> {
    store: new stores.InboxStore()
  }
  handleChange: -> @forceUpdate()
  componentDidMount: ->
    @props.store.on 'change', @handleChange
    @props.store.setRestClient(@props.restClient)
    @props.store.init()
  componentWillUnmount: -> @props.store.removeListener 'change', @handleChange
  handleResize: -> @forceUpdate()
  handleRemove: (index, e) ->
    e.stopPropagation()
    conv = @props.store.getItem(index)
    if confirm($l("deleteMessageConfirmation").replace(/username/, conv.fromProfile.username))
      @props.store.delete(conv.fromProfileGuid)
  handleClick: (index) ->
    conv = @props.store.getItem(index)
    @props.onChangePath("/conversation/#{conv.fromProfileGuid}")

  renderMessage: (index, scrollTop) ->
    @props.store.setScrollTop(scrollTop)
    height = 100
    conv = @props.store.getItem(index)
    loadingMessage = d.div {style: {fontSize: 25, padding: 20}}, "Loading..."
    return loadingMessage unless conv?.fromProfile?

    upgradeToRead = @props.features.billing?.available and !@props.features.messaging?.available unless conv.removed
    profile = conv.fromProfile
    if !conv?.removed && profile.primaryPhoto?
      url = "#{profile.primaryPhoto?.cdnBaseUrl}#{profile.primaryPhoto?.urls?['100x100']}"
    else
      url = $l("genericPhotos.#{profile.gender}")

    text = conv.text
    text = $l("messaging.upgradeToRead") if upgradeToRead
    text = text.replace(/\n/, '') unless conv.removed
    text = $l("removedProfile") if conv.removed

    messageStyle =
      height: height - 1
      position: 'relative'
      backgroundColor: 'white'
      textAlign: 'left'
      overflow: 'hidden'
      width: '100%'
      borderBottom: 'solid 1px black'
      cursor: 'pointer'
    messageStyle.backgroundColor = 'rgb(200, 200, 200)' if conv.removed

    d.div({style: messageStyle, onClick: @handleClick.bind(@, index)}, [
        d.img {src: url, style: {width: 100, height: 98}}, ''
        d.span {style: {position: 'absolute', left: 110, top: 10, color: 'grey', fontWeight: 700}}, profile.username
        d.span {style: {position: 'absolute', left: 110, top: 50, color: 'grey', marginRight: "40px"}}, text
        if conv.deleted
          d.div {style: {position: 'absolute', left: 0, top: 0, width: '100%', height: '100%', backgroundColor: 'rgba(150, 150, 150, 0.7)'}}
        else
          d.i {className: 'fa fa-trash', style: {fontSize: 20, position: 'absolute', right: 20, top: '50%', transform: 'translate(0, -50%)'}, onClick: @handleRemove.bind(@, index)} unless upgradeToRead
      ]...
    )

  render: ->
    d.div {className: 'outer-container'},
      d.div {className: 'inner-container'},
        d.div {className: 'messages-container'},
          if @props.store.getLoadedCount() == 0
            if @props.store.isLoading()
              d.div({className: 'info-message'}, "Loading...")
            else
              d.div({className: 'info-message'}, $l('emptyInbox'))
          else
            d.HtmlListView(
              ref: 'listView'
              numberOfItemsGetter: => @props.store.getLoadedCount()
              itemHeightGetter: => 100
              itemGetter: @renderMessage
              onClick: @handleClick
            )

exports.Conversation = createFactory
  getDefaultProps: -> {
    store: new stores.ConversationStore()
  }
  handleChange: -> @forceUpdate()
  handleViewProfile: (e) ->
    e.preventDefault()
    @props.onChangePath("/profile/#{@props.conversation.conversationWithGuid}")
  componentWillMount: ->
    @props.store.init(@props.conversation)
    conv = @props.store.getConversation(@props.conversation.conversationWithGuid)
    @setState(loadedMessages: conv?.messages?.length)
  componentDidMount: ->
    @props.store.on 'change', @handleChange
    @props.store.setRestClient(@props.restClient)
  componentWillUnmount: -> @props.store.removeListener 'change', @handleChange
  componentDidUpdate: ->
    if (@shouldScrollBottom)
      node = $('body')[0]
      node.scrollTop = node.scrollHeight
  render: ->
    conv = @props.store.getConversation(@props.conversation.conversationWithGuid)
    profile = conv.profileSummary
    unless profile?
      return d.div {className: 'outer-container'}, d.div {className: 'inner-container', style: paddingTop: 20}, d.h2 {}, $l('removedProfile')
    if profile.primaryPhoto?
      url = "#{profile.primaryPhoto?.cdnBaseUrl}#{profile.primaryPhoto?.urls?['100x100']}"
    else
      url = $l("genericPhotos.#{profile.gender}")
    previousMessage = null
    messages = conv.messages
    unless @state?.showAllMessages
      removedMessages = (@state?.loadedMessages || messages.length) - 3
      messages = _.takeRight(messages, messages.length - removedMessages)
    d.div {className: 'outer-container conversation'},
      d.div {className: 'inner-container'},
        d.a {onClick: @handleViewProfile},
          d.div({className: 'profile-summary'},
            d.div {className: "photo #{@props.className}"}, d.img {width: '100%', height: '100%', src: url}
            d.div {className: "username"}, profile.username
            d.div {className: "info"},
              d.span {}, profile.age
              d.Bullet({})
              d.span {}, profile.city || "United States"
          )
        d.div {className: 'messages'},
          if removedMessages? and removedMessages > 0
            d.Button {className: "see-all-messages", onClick: => @setState(showAllMessages:true)}, "See #{removedMessages} older messages"
          _.map(messages, (message) =>
            previousType = previousMessage?.type
            previousMessage = message
            d.div {className: "message #{message.type} #{previousType}-#{message.type}"},
              if message.type=='received'
                d.div {className: "photo"},
                  d.a {onClick: @handleViewProfile},
                    d.img {width: '100%', height: '100%', src: url}
              d.div {className: "text"}, message.text
              d.div {className: "timestamp"}, moment.utc(message.timestamp).from(moment())
          )...
        d.div {className: "send-message"},
          d.textarea {
            placeholder: $l('messaging.sendMessagePlaceholder')
            ref: 'messageText'
            value: @state?.message
            onChange: (e) => @setState(message: $(e.target).val())
          }
          d.Button {
            className: "pill send tiny"
            onClick: =>
              @props.store.sendMessage conv.conversationWithGuid, @state.message, =>
                @shouldScrollBottom = true
                @setState(message: "")
          }, "Send"