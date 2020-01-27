###Deprecated
struct Patient
    intID::Int
    id::String
    age::Int
    diagnosis::String
    treatmentplan::Array{UnplannedVisit}



    Patient(intID::Int,id::String,age::Int,diagnosis::String,treatmentplan::Array{Any}) = new(intID,id,age,diagnosis,treatmentplan)
    Patient(id::String,age::Int,diagnosis::String) = new(0,id,age,diagnosis,[])
    Patient(id::Int) = patient(string(id),100,"")
    Patient(id::String) = Patient(id,100,"")
end

###Deprecated
function Base.:(==)(p1::Patient, p2::Patient)
    return  p1.id == p2.id
end
###Deprecated
function addNewPatient!(patients::Array{Patient},id::String,age::Int,diagnosis::String,treatmentplan::Array{Any})
     push!(patients,Patient(length(patients)+1,id,age,diagnosis,treatmentplan))
 end
