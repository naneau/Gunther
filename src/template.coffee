# Main template class
class Gunther.Template

    # additional DOM parsers, can be used to set up plugins, etc.
    @domParsers = []

    # Create a DOM element
    #
    # Accepts simple class/id descriptors too, in the form of div.foo/div#foo
    @createHtmlElement: (description) ->
        # Tag name to create
        tagName = (description.match /([a-z]+)([\.|\#]?)/i)[1]

        # Create the element
        element = $(document.createElement tagName)

        # Return if element name matches description (avoid further regexing)
        return element if tagName is description

        # Identifier (div#foo)
        id = description.match /\#(-?[_a-zA-Z]+[_a-zA-Z0-9-]*)+/i
        element.attr 'id', (id[0].substring 1) if id?

        # Any and all classes in the description (div.foo.bar)
        classes = description.match /\.(-?[_a-zA-Z]+[_a-zA-Z0-9-]*)/ig
        console.log classes

        # Join up classes
        join = (memo, val) -> memo + ' ' + val.substring 1
        classNameFull = $.trim  _.reduce classes, join, ''

        # Set the class attr
        element.attr 'class', classNameFull

        # Return the element
        element

    # Value for an element whereby both a function and a direct value can be passed
    # scope is optional
    @elementValue: (generator, scope = {}) ->
        return generator.apply scope if typeof generator is 'function'

        generator

    # Generate children for a DOM element
    @generateChildren: (el, childFn, scope) ->

        # Do the actual recursion, setting up the scope proper, and passing the parent element
        childResult = Gunther.Template.elementValue childFn, scope

        # Make sure we get a result in the first place
        return if childResult is undefined

        # If the child generator returns a string, we have to append it as a text element to the current element
        el.append document.createTextNode childResult if typeof childResult isnt 'object'

        # If we get a bound property, we set up the initial value, as well as a change watcher
        if childResult instanceof BoundProperty

            # Initial generated value
            childResult.getValueInEl el

            # Track changes in the bound property
            childResult.bind 'change', (newVal) ->

                # Empty the node for updates
                el.empty()

                # Set the new value
                childResult.getValueInEl el

        # The child is a new View instance, we set up the proper element and render it
        else if childResult instanceof Backbone.View

            # Set the view's element to the current one
            childResult.setElement el

            # Render the view
            childResult.render()

    # Constructor
    constructor: (@fn) -> null

    # Render
    render: (args...) ->

        # Set up a root element, its children will be transferred
        @root = $('<div />')

        # Current element, starts out as the root element, but will change in the tree
        @current = @root

        # Start the template function
        @fn.apply this, args

        # Add all children of root to the element we're supposed to render into
        children = @root.children()

        # Parse dom with the DOM parsers
        for domParser in Gunther.Template.domParsers
            for child in children
                domParser child

        children

    # Render into an element
    #
    # Will return a Backbone.View that can be used/modified to your wishes
    renderInto: (el, args...) ->

        # Append a child for every element @render returns
        ($ el).append child for child in @render args...

        # Return a view
        new Backbone.View
            el: ($ el)

    # Add text to the current element
    #
    # This will create a text node and append it to the current element, the
    # contents of which can be either a string, or a bound property (see
    # @bind())
    text: (text) ->

        # Create text node
        el = document.createTextNode ''

        # Set the contents of the child node
        if typeof text is 'string'
            el.nodeValue = text
        else
            # If a function is passed, call it
            childResult = Gunther.Template.elementValue text, this

            # If we get a bound property, we set up the initial value, as well as a change watcher
            if childResult instanceof BoundProperty
                el.nodeValue = childResult.getValue()
                childResult.bind 'change', (newVal) ->
                    el.nodeValue = newVal

        # Append the child node
        @current.append el

    # Create a child to @current, recurse and add children to it, etc.
    element: (tagName, args...) ->

        # Element we're working on starts out with the current one set up in
        # the "this" scope. This will change in the child rendering, so we need
        # to retain a reference
        current = @current

        # Element to render in
        el = Gunther.Template.createHtmlElement tagName

        # Change current element to the newly created one for our children
        @current = el

        # The last argument
        lastArgument = args[args.length - 1]

        # We have to recurse, if the last argument passed is a function
        if typeof lastArgument is 'function'
            Gunther.Template.generateChildren el, args.pop(), this

        # Bound property passed?
        else if lastArgument instanceof BoundProperty
            Gunther.Template.generateChildren el, args.pop(), this

        # If we get passed a string as last value, set it as the node value
        else if typeof lastArgument is 'string'
            el.append document.createTextNode args.pop()

        # Append it to the current element
        current.append el

        # Set the now current again element in the this scope
        @current = current

        null

    # Set a property
    attribute: (name, value, args...) ->

        # Current element
        el = @current

        # Set up binding for bound properties
        if value instanceof BoundProperty

            # Set the base value
            el.attr name, value.getValue()

            # On change re-set the attribute
            value.bind 'change', (newValue) -> el.attr name, value

        # Else try to set directly
        else
            el.attr name, value

    # Set up an event handler
    on: (event, handler) -> @current.bind event, handler

    # Append an element
    append: (element) ->
        if element instanceof Backbone.View
            # The element is a Backbone view

            # Render it
            element.render()

            # Append its element
            @current.append element.el

        else
            # Assume it can be appended directly
            @current.append element

    # Render a sub-template
    subTemplate: (template, args...) -> template.renderInto @current, args...

    # Bind to a property of a model
    bind: (args...) -> new BoundProperty args...

    # Set up a subview for every item in the collection
    itemSubView: (options) -> new ItemSubView options

    # Aliases for shorter notation
    #
    # Alias for element
    e: (tagName, args...) -> @element tagName, args...

    # Alias for add text
    t: (args...) -> @text args...

    # Attribute
    a: (args...) -> @attribute.apply this, args
    attr: (args...) -> @attribute.apply this, args
