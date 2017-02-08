_ = require('lodash')
React = require('react')
d = _.merge React.DOM, require('./common'), require('./canvas'), require('./profile_list')
{createFactory} = d
stores = require('./stores')
$l = require('./locale')
moment = require('moment')

ProfileContent = createFactory
  value: ->
    return @props.children unless @refs.textarea?
    @refs.textarea.value()
  render: ->
    if @props.editMode
      d.AutoGrowTextArea {ref: 'textarea', defaultValue: @props.children}
    else
      d.span {}, @props.children

AdvancedCriteriaTable = createFactory
  value: -> _.merge {}, @props.children, @state
  handleChange: (field, e) ->
    value = $(e.target).val()
    @setState(_.object [[field, value]])
  render: ->
    d.div({},
      _.map(@props.children, (v, k) =>
        v = @state[k] if @state?[k]?
        rendered =
          label: $l("advancedCriteria.#{k}")
          value: $l("options.#{k}.#{v}") || v if v? and v!=''
        options = $l("options.#{k}")
        if @props.editMode
          if _.isObject(options)
            rendered.value = d.select {ref: k, value: v, onChange: @handleChange.bind(null, k)},
              d.option {}, ""
              _.map(options, (label, option) ->
                d.option {value: option}, label
              )...
          else
            rendered.value = d.input {ref: k, value: rendered.value, onChange: @handleChange.bind(null, k)}
        d.DescriptionList({label: rendered.label}, rendered.value) if (rendered.value? and rendered.value!='') or @props.editable
      )...
    )

EditableSection = (focusProps) -> (Component) -> createFactory
  handleEdit: ->
    @setState(editMode: true)
    focusProps.focusOn(@refs.section.getDOMNode()) if focusProps.focusOn?
  handleCancel: ->
    @setState(editMode: false)
    focusProps.unfocus() if focusProps.unfocus?
  handleSave: ->
    @setState(editMode: false)
    @props.onChange(@refs.component.value()) if @props.onChange?
    focusProps.unfocus() if focusProps.unfocus?
  componentDidMount: ->
    $(@refs.section.getDOMNode()).resize =>
      focusProps.onResize() if focusProps.onResize?
  render: ->
    d.div {ref: 'section', className: "#{@props.className} #{if @state?.editMode then 'edit-mode' else ''}"},
      EditLabel {onEdit: @props.onEdit || @handleEdit, editMode: @state?.editMode, onCancel: @handleCancel, onSave: @handleSave}, @props.label
      Component _.defaults({ref: 'component', editMode: @state?.editMode, editable: true}, @props), @props.children

Section = (Component) -> createFactory
  render: ->
    d.div {className: @props.className},
      d.h3 {}, @props.label if @props.label
      Component _.defaults({ref: 'component'}, @props), @props.children

LookingForTable = createFactory
  value: -> _.merge {}, @props.children, @state
  handleChange: (e) ->
    value = $(e.target).val()
    field = $(e.target).attr('name')
    @setState(_.object [[field, value]])
  render: ->
    if @props.editMode
      d.BulletList {}, [
        d.DropDown {name: 'gender', value: @state?.gender || @props.children.gender, onChange: @handleChange}, $l("gender_plural")
        d.span {},
          "Between "
          d.DropDown {name: 'minAge', value: @state?.minAge || @props.children.minAge, onChange: @handleChange}, ages
          " and "
          d.DropDown {name: 'maxAge', value: @state?.maxAge || @props.children.maxAge, onChange: @handleChange}, ages
        d.DropDown {name: 'distance', value: @state?.distance || @props.children.distance, onChange: @handleChange}, $l("options.distance")
        d.DropDown {name: 'relationshipType', value: @state?.relationshipType || @props.children.relationshipType, onChange: @handleChange}, $l("options.relationshipType")
      ]...
    else
      d.BulletList {}, [
        $l("gender_plural.#{@props.children.gender}")
        d.span {}, ["Between ", d.span({}, @props.children.minAge), " and ", d.span({}, @props.children.maxAge)]...
        $l("options.distance.#{@props.children.distance}")
        $l("options.relationshipType.#{@props.children.relationshipType}")
      ]...


exports.Discover = createFactory
  getDefaultProps: -> {
    store: new stores.DiscoverStore()
  }
  handleChange: (section, values) ->
    updates = _.object [[section, values]]
    @props.restClient.post '', updates
    @setState(updates)
  handleViewProfile: ->
    @props.onChangePath("/profile/#{@props.store.getCurrentProfile().guid}")
  goprofileClick: (profile) ->
    @props.onChangePath("/myprofile")
  handleSendMessage: ->
    @props.onChangePath("/conversation/#{@props.store.getCurrentProfile().guid}")
  componentWillMount: ->
    @props.store.preload(@props.items, @props.totalFound)
  componentDidMount: ->
    @props.store.on 'change', @handleChange
    @props.store.setRestClient(@props.restClient)
  componentWillUnmount: -> @props.store.removeListener 'change', @handleChange
  render: ->
    profile = @props.store.getCurrentProfile()
    status = @props.store.getStatus()
    section = if @props.editable
      EditableSection(
        focusOn: (element) => @refs.focusSection.focus(element)
        unfocus: => @refs.focusSection.unfocus()
        onResize: => @refs.focusSection.handleWindowResize()
      )
    else
      Section
    d.div {className: 'outer-container'}, d.div {className: 'inner-container'},
      d.Button {className: 'finish_profile', onClick: @goprofileClick},
        d.span {}, $l('tooltips.goprofile')
        d.Glyph(glyph: 'arrow-right')
      d.div {className: 'discover'},
        if status == 'loading'
          d.div {className: 'loading'}, d.span {}, $l('loading')
        else if status == 'empty'
          d.div {className: 'empty'}, d.span {}, $l('emptyDiscover')
        d.div {className: 'random_title'}, d.span(), "Random Match"
        d.div {className: 'photos'},
          d.div {className: 'current'},
            d.div {className: 'photo', style: backgroundImage: "url(#{profile?.primaryPhoto?.cdnBaseUrl}#{profile?.primaryPhoto?.urls?['300x300']})"},
          d.div {className: 'buttons'},
            d.Button {className: "like-profile square", onClick: => @props.store.like(); return},
              d.Glyph(glyph: 'star')
              d.span {className: 'button-label'}, "Like"
            d.Button {className: "send-message square", onClick: @handleSendMessage},
              d.Glyph(glyph: 'comment')
              d.span {className: 'button-label'}, "Message"
            d.Button {className: "send-message square", onClick: @handleViewProfile},
              d.Glyph(glyph: 'comment')
              d.span {className: 'button-label'}, "View"
            d.Button {className: "hide-profile square", onClick: => @props.store.hide(); return},
              d.Glyph(glyph: 'share')
              d.span {className: 'button-label'}, "Skip"

        d.div {className: "content-and-details #{if (profile?.content?.length? || 0) == 0 then 'no-content' else 'has-content'}"}, [
          d.div {className: 'content'}, _.map(profile.content || [], (item) =>
            section(ProfileContent) {
              className: 'item'
              label: $l("content.#{item.type}")
              onChange: @handleChangeContent.bind(null, item.type)
            }, @state?["content_#{item.type}"] || item.content
          )...
          d.div {className: 'details'},
            section(LookingForTable) {
              className: 'looking-for'
              label: 'Looking For'
              onChange: @handleChange.bind(null, 'lookingFor')
            }, _.merge {}, profile.lookingFor, @state?.lookingFor
            section(AdvancedCriteriaTable) {
              className: 'my-details'
              label: 'My Details'
              onChange: @handleChange.bind(null, 'advancedCriteria')
            }, _.merge {}, profile.advancedCriteria, (@state?.advancedCriteria || {})
        ]...