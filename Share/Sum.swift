//
//  Sum.swift
//  Share
//
//  Created by 顾艳华 on 2023/7/5.
//

import SwiftUI

struct Sum: View {
    let fav: Fav
    let search: String
    let screenWidth = UIScreen.main.bounds.width
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Html.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Html>
    
    @Environment(\.managedObjectContext) private var viewContext
    func fav(condition: Fav, isFav: Bool) -> Bool {
        switch condition {
        case .all:
            return true
        case .id(let f):
            return isFav == f
        }
    }
    var body: some View {
        List {
            ForEach(items.filter{(($0.title ?? "title").contains(search.lowercased()) || search == "") && fav(condition: self.fav, isFav: $0.fav)}) { item in
                let title = item.title ?? "No Title" == "" ? "No Title" : item.title ?? "No Title"
                NavigationLink {
                    VStack {
                        Text(title)
                            .font(.title)
                            .bold()
                        HStack {
                            Text(item.url ?? "url")
                                .italic()
                                .foregroundStyle(.gray)
                                .font(.callout)
                            Spacer()
                        }
                        //                            .padding(.horizontal)
                        if item.thumbnail != "" {
                            AsyncImage(url: URL(string: item.thumbnail ?? "thumbnail")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 10)
                                    .foregroundColor(.gray)
                            }
                            .frame(width: screenWidth - 22 , height: screenWidth * 2 / 3)
                        } else {
                            EmptyView()
                        }
                        ScrollView {
                            Text(item.summary ?? "summary")
                        }
                        Spacer()
                    }
                    .padding()
                    .toolbar {
                        ToolbarItem {
                            ShareLink(item: URL(string: item.url!)!, message: Text(item.summary!))
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button{
                                if let url = URL(string: item.url!) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Image(systemName: "safari")
                            }
                        }
                    }
                } label: {
                    VStack{
                        HStack{
                            VStack(alignment: .leading){
                                Text(title)
                                    .bold()
                                    .lineLimit(3)
                                Text(item.url ?? "url")
                                    .italic()
                                    .foregroundStyle(.gray)
                                    .font(Font.system(size: 10))
//                                Text("\(i)")
                                
                            }
                            
                            Spacer()
                            AsyncImage(url: URL(string: item.thumbnail ?? "thumbnail")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 10)
                                    .foregroundColor(Color(red: Double.random(in: 0..<1), green: Double.random(in: 0..<1), blue: Double.random(in: 0..<1)))
                            }
//                            RoundedRectangle(cornerRadius: 10)
//                                .foregroundColor(Color(red: Double.random(in: 0..<1), green: Double.random(in: 0..<1), blue: Double.random(in: 0..<1)))
                                .frame(width: 150, height: 100)
                            
                        }
                        HStack {
                            Spacer()
                            Image(systemName: item.fav ? "bookmark.fill" : "bookmark")
                                .onTapGesture {
                                    item.fav.toggle()
                                    updateItem(item: item)
                                }
                                .padding(.horizontal)
                            Image(systemName: "trash")
                                .onTapGesture {
                                    deleteItems(item: item)
                                }
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
//        .refreshable {
//            i += 1
//        }
    }
    
    private func deleteItems(item: Html) {
        withAnimation {
            viewContext.delete(item)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func updateItem(item: Html) {
        withAnimation {

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

enum Fav {
    case all
    case id(Bool)
}

