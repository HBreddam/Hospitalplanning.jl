struct Patient
    id::String
    age::Int
    diagnosis::String
    treatmentplan::Array{Any}

    Patient(id::String,age::Int,diagnosis::String,treatmentplan::Array{Any}) = new(id,age,diagnosis,treatmentplan)
    Patient(id::String,age::Int,diagnosis::String) = new(id,age,diagnosis,[])
    Patient(id::Int) = patient(string(id),100,"")
    Patient(id::String) = Patient(id,100,"")
end

function Base.:(==)(p1::Patient, p2::Patient)
    return  p1.id == p2.id
end
