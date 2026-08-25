using StructEditor
using Bonito
using ShoelaceWidgets

#=
In this example we store our data in `Project.description`, but we store this data in a compacted form.  
Therefore we'd like to be able to move the data into an expanded form/struct and use that for editing.
This example below shows how to do that.  The requirements are:

1. Define the functions that transform data in both directions, from compacted to expanded and back.  In this
    case we define `description_to_expand(x::String)` and `expand_to_description(x::ExpandedDescription)`
2. Define a specific `make_control!` definition for the special field, in this case it's `Project.description`.  
    We then dispatch to the generic `make_control!` function providing:
        a) the type to dispatch on and create the control for, in this case `ExpandedDescription`
        b) the keyword: to_field=expand_to_description
        c) the keyword: to_widget=description_to_expand
=#


# Here is our main source data, the description is a compacted form of the information
@kwdef struct Project
    description::String = "[Big Project] This is a big project that will take many months. {Expected to start mid-year} #big #project"
end

# Here we define a struct to make editing the description easier, expanding the description to it's separate parts
struct ExpandedDescription
    title::String
    abstract::String
    notes::String
    tags::Vector{String}
end

# Binding requires that an isequals is defined for the struct to protect against circular data writing
Base.:(==)(a::ExpandedDescription, b::ExpandedDescription) = 
    a.title == b.title && a.abstract == b.abstract && a.notes == b.notes && a.tags == b.tags

# for tags we want to be able to add new tags, they are strings so editing in place is automatically supported
StructEditor.add_mode(::Type{ExpandedDescription}, ::Val{:tags}) = FunctionAdd

function description_to_expand(x::String)
    #title
    b1 = findfirst(==('['), x)
    b2 = findfirst(==(']'), x)

    #notes
    n1 = b2 + findfirst(==('{'), x[b2+1:end])
    n2 = n1 + findfirst(==('}'), x[n1+1:end])

    #tags
    t1 = n2 + findfirst(==('#'), x[n2+1:end])
    
    title = x[b1+1:prevind(x, b2)]
    abstract = x[b2+1:prevind(x, n1)]
    notes = x[n1+1:prevind(x, n2)]
    
    tags_line = x[t1+1:end]
    tags = strip.(split(tags_line, '#'))
    
    return ExpandedDescription(title, abstract, notes, tags)
end

add_hash(x::String) = "#$x"

function expand_to_description(x::ExpandedDescription)
    tags_line = if isempty(x.tags)
        "#"
    else
        join(add_hash.(x.tags), ' ')
    end
    
    return "[$(x.title)] $(x.abstract) {$(x.notes)} $tags_line"
end


# Here we create the expanded control
function StructEditor.make_control!(state::ApplicationState{Project}, ::Val{:description}, dirty=identity)
    sname = :description
    return StructEditor.make_control!(state, ExpandedDescription, sname, dirty; 
                to_field=expand_to_description, 
                to_widget=description_to_expand)
end


debugger = Ref{ApplicationState}()
editor(Project(); debugger)

#=
Make changes in the editor, then it's possible to see the changes reflected...
debugger[].value[]

Now run this and see the changes reflected in the control...
debugger[].value[] = Project("[Project A] This is project A {Don't forget to call the project manager} #tag1 #tag2")
=#
