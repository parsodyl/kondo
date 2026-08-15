# Kondo Architecture Flowchart 🔍

This document provides the full, detailed architecture flow for the **Kondo** pattern, including component responsibilities and interaction flows across layers.

## Interactive Flow Diagram

```mermaid
graph TD
    subgraph UI Layer
        V(Flutter View: Widgets)
        P(Native View: Plugins)    
    end

    subgraph Kondo Triad
        H(Hako: Feature State Holder & Orchestrator)
        I(Interactor: Business Logic & Data Adapter)
        R(Reactor: Side Effects Handler)
    end

    subgraph Data Layer
        S(Services: e.g., API, DB, Device)
        RP(Repositories: e.g., Cached Data, Shared App State)
    end

    %% --- Flow ---

    %% View -> Hako (User Events)
    V -- User Events \n(e.g., onTap, onChanged) --> H

    %% Hako -> Interactor (Business Logic Requests)
    H -- Business Logic Requests --> I

    %% Interactor -> Data Layer (Data Fetch/Update)
    I -- Data Requests --> S
    I -- Data Fetch/Update --> RP

    %% Data Layer -> Interactor (Results)
    S -- Data Responses --> I
    RP -- Results \n(e.g., Futures, Streams) --> I

    %% Interactor -> Hako (Processed Data/Streams)
    I -- Processed Data / Streams --> H

    %% Hako -> Reactor (Side Effect Commands)
    H -- Side Effect Commands --> R
    
    %% Reactor -> Hako (User Choices Results)
    R -- User Choices Results \n(e.g., Dialog Confirmations, File picking) --> H

    %% Reactor -> View (Execute Internal UI Side Effects)
    R -- Internal Actions \n(e.g., Navigation, Dialogs, Snackbars) --> V
    
    %% Reactor -> Visual Plugins (Execute External UI Side Effects)
    R -- External Actions \n(e.g., Opening Links, Taking Photos) --> P

    %% Hako's internal state management
    H -- Updates State --> V
    V -- Renders State --> H
```

---

## Flow Breakdown

1. **User Interaction**:
   - The user interacts with the UI (`Flutter View`), triggering **User Events** into `Hako`.
2. **Business Delegation**:
   - `Hako` delegates domain and business tasks by making **Business Logic Requests** to the `Interactor`.
3. **Data Access**:
   - `Interactor` fetches or mutates data via **Services** (APIs, Database, Device) and **Repositories** (Cache, Shared App State).
   - Responses and streams flow back from the data layer into the `Interactor`, which transforms them into domain-appropriate models and streams for `Hako`.
4. **State Orchestration**:
   - `Hako` receives processed data, updates the feature state, and emits state updates to the `Flutter View`.
5. **Side Effects**:
   - When actions require navigation, dialogs, snackbars, or external device plugins, `Hako` commands the `Reactor`.
   - The `Reactor` executes context-aware side effects directly against `Flutter View` or native system plugins, returning any user choices (such as dialog confirmations or file picking) back to `Hako`.
