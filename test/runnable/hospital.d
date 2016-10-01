// REQUIRED_ARGS:

// NOTE: the shootout appears to be BSD licensed content.
// Including this in the test suite based on that license.

/* The Great Computer Language Shootout
   http://shootout.alioth.debian.org/

   Unoptimised reference implementation

   contributed by Isaac Gouy
*/

import std.stdio, std.string, std.conv;
import core.memory;

int main(string[] args)
{
    //std.gc.setV1_0();
    int n = args.length > 1 ? to!int(args[1]) : 1000;

    HealthcareRegion healthcareSystem = HealthcareRegion.Create();

    for(int i = 0; i < n; i++)
        healthcareSystem.TransferPatients();

    Totals t = healthcareSystem.AccumulateTotals();

    writeln("Patients: ", t.patients );
    writeln("Time:     ", t.hospitalTime );
    writeln("Visits:   ", t.hospitalVisits );

    if (n == 1000)
    {
        assert(t.patients == 102515);
        assert(t.hospitalTime == 33730654);
        assert(t.hospitalVisits == 106371);
    }
    return 0;
}

class HealthcareRegion
{
public:
    static HealthcareRegion Create()
    {
        return HealthcareRegion.Create(LEVELS, 0, 42);
    }

    static HealthcareRegion Create(int level, int seed1, int seed2)
    {
        HealthcareRegion r = null;

        if(level > 0)
        {
            r = new HealthcareRegion(level, seed1*seed2);
            for(ptrdiff_t i = r.districts.length-1; i >= 0; i--)
                r.districts[i] = Create(level-1, cast(int)((seed1*4)+i+1), seed2);
        }
        return r;
    }

    this(int level, int s)
    {
        districts = new HealthcareRegion[DISTRICTS];
        localHospital = new Hospital(level == LEVELS, level, s);
    }

private:
    enum int LEVELS = 5, DISTRICTS = 4;
    HealthcareRegion[] districts;
    Hospital localHospital;

package:
    Patient[] TransferPatients()
    {
        for(ptrdiff_t i = districts.length-1; i >= 0; i--)
            if(districts[i])
                foreach(Patient p; districts[i].TransferPatients().dup)
                    localHospital.NewArrival(p);

        localHospital.TriageExaminationTreatment();

        return localHospital.RegionalTransferPatients();
    }

    Totals AccumulateTotals()
    {
        Totals t = new Totals();
        for(ptrdiff_t i = districts.length-1; i >= 0; i--)
            if(districts[i])
                t += districts[i].AccumulateTotals();

        localHospital.AccumulateTotals(t);

        return t;
    }
}

class Hospital
{
    public this(bool hasNoRegionalHospital, int level, int seed)
    {
        this.hasNoRegionalHospital = hasNoRegionalHospital;
        availableStaff = 1 << (level - 1);
        discharged = new Totals();
        this.seed = seed;
    }

package:
    void TriageExaminationTreatment()
    {
        DischargePatients();
        TreatOrTransferPatients();
        TriagePatients();

        if(genRandom(1.0) > 0.7)
        {   Patient p = new Patient();
            NewArrival(p);
        }
    }

    Patient[] RegionalTransferPatients()
    {
        return transfers;
    }

    void AccumulateTotals(Totals t)
    {
        foreach(Patient p; triage) t.Plus(p);
        foreach(Patient p; examination) t.Plus(p);
        foreach(Patient p; treatment) t.Plus(p);
        t += discharged;
    }

    void NewArrival(Patient p)
    {
        p.hospitalVisits++;
        if(availableStaff > 0)
        {
            availableStaff--;
            examination ~= p;
            p.remainingTime = 3;
            p.hospitalTime += 3;
        } else {
            triage ~= p;
        }
    }

private:
    Patient[] triage, examination, treatment, transfers;
    Totals discharged;
    int availableStaff;
    bool hasNoRegionalHospital;

    void DischargePatients()
    {
        for(ptrdiff_t i = treatment.length-1; i >= 0; i--)
        {
            Patient p = treatment[i];
            p.remainingTime -= 1;
            if(!p.remainingTime)
            {
                availableStaff++;
                treatment = treatment[0..i] ~ treatment[i+1..$];
                discharged.Plus(p);
            }
        }
    }

    void TreatOrTransferPatients()
    {
        delete transfers;

        for(ptrdiff_t i = examination.length-1; i >= 0; i--)
        {
            Patient p = examination[i];
            p.remainingTime -= 1;

            if(!p.remainingTime)
            {
                // no transfer
                if(genRandom(1.0) > 0.1 || hasNoRegionalHospital)
                {
                    examination = examination[0..i] ~ examination[i+1..$];
                    treatment ~= p;
                    p.remainingTime = 10;
                    p.hospitalTime += 10;
                } else {
                // transfer
                    availableStaff++;
                    examination = examination[0..i] ~ examination[i+1..$];
                    transfers ~= p;
                }
            }
        }
    }

    void TriagePatients()
    {
        for(ptrdiff_t i = triage.length-1; i >= 0; i--)
        {
            Patient p = triage[i];
            if(availableStaff > 0)
            {
                availableStaff--;
                p.remainingTime = 3;
                p.hospitalTime += 3;
                triage = triage[0..i] ~ triage[i+1..$];
                examination ~= p;
            } else {
                p.hospitalTime++;
            }
        }
    }

    int seed = 42;
    const int IM = 139968;
    const int IA = 3877;
    const int IC = 29573;
    double genRandom(double max)
    {
        return(max * (seed = (seed * IA + IC) % IM) / IM);
    }
}

class Patient
{
    package int remainingTime, hospitalTime, hospitalVisits;
}

class Totals
{
    public Totals opAddAssign(Totals b)
    {
        patients += b.patients;
        hospitalTime += b.hospitalTime;
        hospitalVisits += b.hospitalVisits;
        return this;
    }

package:
    long patients, hospitalTime, hospitalVisits;

    void Plus(Patient p)
    {
        patients++;
        hospitalTime += p.hospitalTime;
        hospitalVisits += p.hospitalVisits;
    }
}
