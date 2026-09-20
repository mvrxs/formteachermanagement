//
//  CalendarioTutoriasView.swift
//  GestionTutorial
//
//  Calendario mensual estilo Calendario de macOS: cada día muestra sus tutorías
//  dentro de la celda. Al pulsar una, se selecciona y el detalle la reemplaza.
//

import SwiftUI
import SwiftData

struct CalendarioTutoriasView: View {
    @Binding var seleccion: Tutoria?

    @Query(sort: \Tutoria.fecha, order: .forward)
    private var tutorias: [Tutoria]

    @State private var mesVisible: Date = .now

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "es_ES")
        c.firstWeekday = 2          // lunes
        return c
    }

    private let simbolosDia = ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"]
    private let maxEventosVisibles = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cabeceraMes
            encabezadoDias
            rejilla
        }
        .padding(20)
        .navigationTitle("Calendario de tutorías")
    }

    // MARK: - Cabecera

    private var cabeceraMes: some View {
        HStack {
            Text(mesVisible.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "es_ES"))).capitalized)
                .font(.largeTitle.bold())
            Spacer()
            Button { cambiarMes(-1) } label: { Image(systemName: "chevron.left") }
            Button("Hoy") { mesVisible = .now }
            Button { cambiarMes(1) } label: { Image(systemName: "chevron.right") }
        }
        .buttonStyle(.bordered)
    }

    private var encabezadoDias: some View {
        HStack(spacing: 0) {
            ForEach(simbolosDia, id: \.self) { s in
                Text(s)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)
            }
        }
    }

    // MARK: - Rejilla

    private var rejilla: some View {
        VStack(spacing: 0) {
            ForEach(Array(semanas.enumerated()), id: \.offset) { _, semana in
                HStack(spacing: 0) {
                    ForEach(semana, id: \.self) { dia in
                        celda(dia)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
        .overlay(Rectangle().stroke(Color.separadorSistema, lineWidth: 0.5))
    }

    private func celda(_ dia: Date) -> some View {
        let delMes = cal.isDate(dia, equalTo: mesVisible, toGranularity: .month)
        let esHoy = cal.isDateInToday(dia)
        let delDia = tutoriasDe(dia)
        let visibles = delDia.prefix(maxEventosVisibles)
        let extra = delDia.count - visibles.count

        return VStack(alignment: .leading, spacing: 2) {
            // Número del día, arriba a la derecha.
            HStack {
                Spacer()
                Text("\(cal.component(.day, from: dia))")
                    .font(.callout)
                    .fontWeight(esHoy ? .bold : .regular)
                    .foregroundStyle(esHoy ? Color.white : (delMes ? Color.primary : Color.secondary.opacity(0.5)))
                    .frame(width: 24, height: 24)
                    .background {
                        if esHoy { Circle().fill(.red) }
                    }
            }

            // Eventos del día.
            ForEach(Array(visibles)) { tutoria in
                eventoFila(tutoria)
            }
            if extra > 0 {
                Text("y \(extra) más")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(delMes ? Color.clear : Color.separadorSistema.opacity(0.08))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.separadorSistema).frame(height: 0.5)
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.separadorSistema).frame(width: 0.5)
        }
    }

    private func eventoFila(_ tutoria: Tutoria) -> some View {
        let color: Color = tutoria.realizada ? .green : .orange
        return Button {
            seleccion = tutoria
        } label: {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 3, height: 12)
                Text(tutoria.alumno?.nombreCompleto ?? "Tutoría")
                    .font(.caption2)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(tutoria.fecha.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: .rect(cornerRadius: 4))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fechas

    private func cambiarMes(_ delta: Int) {
        if let nuevo = cal.date(byAdding: .month, value: delta, to: mesVisible) {
            mesVisible = nuevo
        }
    }

    private func tutoriasDe(_ dia: Date) -> [Tutoria] {
        tutorias
            .filter { cal.isDate($0.fecha, inSameDayAs: dia) }
            .sorted { $0.fecha < $1.fecha }
    }

    private var semanas: [[Date]] {
        stride(from: 0, to: diasDelMes.count, by: 7).map {
            Array(diasDelMes[$0 ..< min($0 + 7, diasDelMes.count)])
        }
    }

    private var diasDelMes: [Date] {
        guard let intervalo = cal.dateInterval(of: .month, for: mesVisible) else { return [] }
        let primerDia = cal.startOfDay(for: intervalo.start)
        let numDias = cal.range(of: .day, in: .month, for: mesVisible)?.count ?? 30
        let weekdayPrimero = cal.component(.weekday, from: primerDia)
        let offset = (weekdayPrimero - cal.firstWeekday + 7) % 7

        var dias: [Date] = []
        for i in stride(from: offset, to: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: primerDia) { dias.append(d) }
        }
        for d in 0..<numDias {
            if let dia = cal.date(byAdding: .day, value: d, to: primerDia) { dias.append(dia) }
        }
        while dias.count % 7 != 0, let ultimo = dias.last,
              let siguiente = cal.date(byAdding: .day, value: 1, to: ultimo) {
            dias.append(siguiente)
        }
        return dias
    }
}
