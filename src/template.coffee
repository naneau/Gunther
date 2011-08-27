# Main template class
class Gunther.Template

    # Create a DOM element
    @createHtmlElement: (tagName) -> $("<#{tagName} />")

    # Add attributes to a DOM element
    @addAttributes: (el, attributes) ->
        # For every attribute object set
        for attribute in attributes
            for attributeName, attributeValue of attribute

                # Bind events
                if _.include Gunther.HTML.eventNames, attributeName
                    el.bind attributeName, (args...) ->
                        attributeValue args...

                # See if we get a BoundProperty, which we bind to (and set)
                else if attributeValue instanceof BoundProperty
                    # Set the base attribute
                    el.attr attributeName, attributeValue.getValue()
                    # On change re-set the attribute
                    attributeValue.bind 'change', (newValue) -> el.attr attributeName, newValue

                # Else try to set directly
                else
                    el.attr attributeName, attributeValue

    # Generate children for a DOM element
    @generateChildren: (el, childFn, scope) ->
        # Do the actual recursion, setting up the scope proper, and passing the parent element
        childResult = childFn.apply scope
        console.log childResult
        # If the child generator returns a string, we have to append it as a text element to the current element
        el.append childResult if typeof childResult isnt 'object'

        # If we get a bound property, we set up the initial value, as well as a change watcher
        if childResult instanceof BoundProperty
            el.html childResult.getValue()
            childResult.bind 'change', (newVal) ->
                el.html newVal

        # The child is a new View instance, we set up the proper element and render it
        else if childResult instanceof Backbone.View
            childResult.el = el
            childResult.render()

    # Constructor
    constructor: (@fn) -> null

    # Render
    render: (args...) ->
        # Set up a root element, its children will be conferred
        @root = $('<div />')

        # Current element, starts out as the root element, but will change in the tree
        @current = @root

        # Start the template function
        @fn.apply this, args

        # Add all children of root to the element we're supposed to render into
        @root.children()
        # Do we remove them from root afterwards?
        #@root.remove()

    # Render into an element
    #
    # Will return a Backbone.View that can be used/modified to your wishes
    renderInto: (el, args...) ->
        el.append child for child in @render args...

        # Return a view
        new Backbone.View
            el: el

    # Create a child to @current, recurse and add children to it, etc.
    createChild: (tagName, args...) ->
        # Element we're working on starts out with the current one set up in
        # the this scope, but will change in the child, so we keep a copy here
        current = @current

        # Element to render in
        el = Gunther.Template.createHtmlElement tagName

        # Change current element to the newly created one for our children
        @current = el

        # We have to recurse, if the last argument passed is a function
        Gunther.Template.generateChildren el, args.pop(), this if typeof args[args.length - 1] is 'function'

        # Set up the attributes for the element
        Gunther.Template.addAttributes el, args

        # Append it to the current element
        current.append el

        # Set the now current again element in the this scope
        @current = current

        null

    # Bind to a property of a model
    #
    # When the property changes the contents are refreshed with the new value.
    # Additionally you can provide a "value" function, that gets called to
    # create the new value
    bind: (args...) -> new BoundProperty args...

    # Set up a subview for every item in the collection
    #
    # This ensures that only one view/template is rendered for every item,
    # where the view can manage a DOM element which is unchanging (the view
    # does not get re-rendered when elements are added to/removed from the
    # collection)
    itemSubView: (collection, key, template) -> new ItemSubView
        model: collection
        key: key
        template: template

# Set up all HTML elements as functions
for htmlElement in Gunther.HTML.elements
    do (htmlElement) -> # gotta love for...do :)
        Gunther.Template::[htmlElement] = (args...) ->
            @createChild htmlElement, args...

# Export Gunther to the global scope
window.Gunther = Gunther
