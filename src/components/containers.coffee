_ = require('lodash')
React = require('react')
dom = React.DOM
common = require('./common')

exports.HtmlListView = common.createFactory
  componentDidMount: ->
    @setState(size: @getContainerBoundingRect())
    @setState(scrollTop: 0)
    @forceUpdate()
    $(window).on "resize", @handleWindowResize
    $(window).on "scroll", @handleWindowScroll

  componentWillUnmount: ->
    $(window).off "resize", @handleWindowResize
    $(window).off "scroll", @handleWindowScroll

  componentDidUpdate: ->
    unless @state?.size?
      @setState(size: @getContainerBoundingRect())
      @forceUpdate()

  handleWindowScroll: (e) ->
    @setState(scrollTop: $(window).scrollTop())
    @forceUpdate()

  handleWindowResize: ->
    @setState(size: null)
    @forceUpdate()

  render: ->
    containerStyle = _.merge(
      position: 'relative', @props.style
    )
    unless @state?.size?
      emptyContainer =
        dom.div {id: @props.id, ref: 'container', className: @props.className, style: {position: 'relative', height: '100%'}},
          dom.div {ref: 'listView'}
      return emptyContainer

    itemHeight = @calculateItemHeight()
    itemCount = @calculateNumberOfItems()
    contentHeight = itemCount * itemHeight
    scrollTop = @state.scrollTop
    startIndex = Math.max ~~(scrollTop / itemHeight), 0
    offsetTop = startIndex * itemHeight
    size = @state.size
    endIndex = startIndex + ~~((size.height + scrollTop % itemHeight) / itemHeight)
    dom.div {id: @props.id, ref: 'container', className: @props.className, style: containerStyle},
      dom.div {ref: 'listView', style: {paddingTop: "#{offsetTop}px", height: "#{contentHeight}px"}},
        _.map([startIndex..Math.min(endIndex, itemCount - 1)], (itemIndex) =>
          @renderItem(itemIndex, scrollTop)
        )...

  renderItem: (itemIndex)->
    @props.itemGetter(itemIndex)

  calculateItemHeight: ->
    return @__cachedItemHeight if @__cachedItemHeight?
    @__cachedItemHeight = @props.itemHeightGetter()

  calculateNumberOfItems: ->
    @props.numberOfItemsGetter()

  getContainerBoundingRect: -> @refs.container.getDOMNode().getBoundingClientRect();