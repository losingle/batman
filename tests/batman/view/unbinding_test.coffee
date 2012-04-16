helpers = if typeof require is 'undefined' then window.viewHelpers else require './view_helper'

QUnit.module "Batman.DOM.AbstractBinding: Unbinding for memory saftey"

test "addEventListener and removeEventListener store and remove callbacks using Batman.data", ->
  div = document.createElement 'div'
  f = ->

  Batman.DOM.addEventListener div, 'click', f
  listeners = Batman._data div, 'listeners'
  ok ~listeners.click.indexOf f

  Batman.DOM.removeEventListener div, 'click', f
  listeners = Batman._data div, 'listeners'
  ok !~listeners.click.indexOf f

asyncTest "bindings are kept in Batman.data and destroyed when the node is removed", 6, ->
  context = new Batman.Object bar: true
  context.accessor 'foo', (spy = createSpy -> @get('bar'))
  helpers.render '<div data-addclass-foo="foo"><div data-addclass-foo="foo"></div></div>', context, (node) ->
    ok spy.called

    parent = node[0]
    child = parent.childNodes[0]
    for node in [child, parent]
      bindings = Batman._data node, 'bindings'
      ok bindings.length > 0

      Batman.DOM.removeNode node
      deepEqual Batman._data(node), {}

    context.set('bar', false)
    equal spy.callCount, 1
    QUnit.start()

asyncTest "iterators are kept in Batman.data and destroyed when the parent node is removed", 5, ->
  context = new Batman.Object bar: true
  set = null
  context.accessor 'foo', (setSpy = createSpy -> set = new Batman.Set @get('bar'), @get('bar'))
  helpers.render '<div id="parent"><div data-foreach-x="foo"></div></div>', context, (node) ->
    equal setSpy.callCount, 1  # Cached, so only called once

    parent = node[0]
    toArraySpy = spyOn(set, 'toArray')

    Batman.DOM.removeNode(parent)
    deepEqual Batman._data(parent), {}

    context.set('bar', false)
    equal setSpy.callCount, 1

    equal toArraySpy.callCount, 0
    set.fire('change')
    equal toArraySpy.callCount, 0
    QUnit.start()

asyncTest "Batman.DOM.Style objects are kept in Batman.data and destroyed when their node is removed", ->
  context = Batman
    styles: new Batman.Hash(color: 'green')

  styles = null
  context.accessor 'css', (setSpy = createSpy -> styles = @styles)
  helpers.render '<div data-bind-style="css"></div>', context, (node) ->
    equal setSpy.callCount, 1  # Cached, so only called once

    node = node[0]
    itemsAddedSpy = spyOn(context.get('styles'), 'itemsWereAdded')

    Batman.DOM.removeNode(node)
    deepEqual Batman._data(node), {}

    context.set('styles', false)
    equal setSpy.callCount, 1

    equal itemsAddedSpy.callCount, 0
    styles.fire('itemsWereAdded')
    equal itemsAddedSpy.callCount, 0
    QUnit.start()

asyncTest "listeners are kept in Batman.data and destroyed when the node is removed", 8, ->
  context = new Batman.Object foo: ->

  helpers.render '<div data-event-click="foo"><div data-event-click="foo"></div></div>', context, (node) ->
    parent = node[0]
    child = parent.childNodes[0]
    for n in [child, parent]
      listeners = Batman._data n, 'listeners'
      ok listeners.click.length > 0

      if Batman.DOM.hasAddEventListener
        spy = spyOn n, 'removeEventListener'
      else
        # Spoof detachEvent because typeof detachEvent is 'object' in IE8, and
        # spies break because detachEvent.call blows up
        n.detachEvent = ->
        spy = spyOn n, 'detachEvent'

      Batman.DOM.removeNode n

      ok spy.called
      deepEqual Batman.data(n), {}
      deepEqual Batman._data(n), {}

    QUnit.start()

asyncTest "bindings added underneath other bindings notify their parents", ->
  context = Batman
    foo: "foo"
    bar: "bar"

  class TestBinding extends Batman.DOM.AbstractBinding
    @instances = []
    constructor: ->
      @childBindingAdded = createSpy()
      super
      @constructor.instances.push @

  Batman.DOM.readers.test = -> new TestBinding(arguments...)
  source = '''
    <div data-test="true">
      <div data-test="true">
        <p data-bind="foo"></p>
        <p data-bind="bar"></p>
      </div>
    </div>
  '''

  helpers.render source, context, (node, view) ->
    equal TestBinding.instances.length, 2
    equal TestBinding.instances[0].childBindingAdded.callCount, 3
    calls = TestBinding.instances[0].childBindingAdded.calls
    ok calls[0].arguments[0] instanceof TestBinding
    ok calls[1].arguments[0] instanceof Batman.DOM.AbstractBinding
    ok calls[1].arguments[0].get('filteredValue'), 'foo'
    ok calls[2].arguments[0] instanceof Batman.DOM.AbstractBinding
    ok calls[2].arguments[0].get('filteredValue'), 'bar'

    equal TestBinding.instances[1].childBindingAdded.callCount, 2
    calls = TestBinding.instances[1].childBindingAdded.calls
    ok calls[0].arguments[0] instanceof Batman.DOM.AbstractBinding
    ok calls[0].arguments[0].get('filteredValue'), 'foo'
    ok calls[1].arguments[0] instanceof Batman.DOM.AbstractBinding
    ok calls[1].arguments[0].get('filteredValue'), 'bar'
    QUnit.start()
