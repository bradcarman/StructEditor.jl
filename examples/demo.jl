using StructEditor

@enum Gender Male Female

@kwdef struct Person
    name::String = ""
    age::Int = 0
    gender::Gender = Male
end

Base.show(io::IO, p::Person) = print(io, "name: $(p.name), age=$(p.age), $(p.gender)")

@kwdef struct Team
    name::String = ""
    people::Vector{Person} = Person[]
end

StructEditor.add_mode(::Type{Team}, ::Val{:people}) = FunctionAdd
StructEditor.edit_mode(::Type{Team}, ::Val{:people}) = DialogEdit

team = Team("Team Julia", Person[])
editor(team)

# ======================
# Preserving State
# ======================

file="examples/demo.json"
save_function = StructEditor.SaveFunction(;file)
editor(team; save_function)

# ======================
# Loading from file
# ======================

editor(file, Team)
viewer(file, Team)


# ======================
# Adding complexity
# ======================

using WGLMakie
sname = :people
function StructEditor.make_control!(state::StructEditor.ApplicationState{Team}, ::Val{sname}, dirty=identity)
    
    val = getproperty(state.value[], sname)
    type = typeof(val)
    
    control = StructEditor.make_control!(state, type, sname, dirty )


    people = @lift(getproperty($(state.value), sname))
    
    n_total = @lift(length($people))
    n_males = @lift($n_total == 0 ? 0.0 : 2pi*length(filter(x->x.gender == Male, $people))/$n_total)
    n_females = @lift($n_total == 0 ? 0.0 : 2pi*length(filter(x->x.gender == Female, $people))/$n_total)

    array = @lift([$n_males, $n_females])
    
    colors = [:blue, :purple]
    f = Figure(size=(300,300))
    ax = Axis(f[1,1])
    pie!(ax, array, normalize=false, color = [:blue, :purple], label = [string(s) => (; color = c) for (s,c) in zip(instances(Gender), colors)])
    axislegend(ax)
    hidedecorations!(ax)
    

    return [control, f]
end

editor(team; save_function)


# ======================
# Building a web app
# ======================
using Bonito

server = Bonito.Server("0.0.0.0", 8080)
url = editor(team; 
        save_function, 
        server, 
        mode=StructEditor.online, 
        path="/", 
        icon="https://icons.getbootstrap.com/assets/icons/pencil.svg", 
        title="Team Editor")
Bonito.HTTPServer.openurl(url)